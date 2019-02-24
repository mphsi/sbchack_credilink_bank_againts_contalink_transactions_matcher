require 'date'
# todo: add doc
class SecurityPointMatcher
  include ExternalServicesMethods

  attr_reader :account_number, :company_rfc, :contalink_movements, :bank_movements

  def initialize(account_number, company_rfc)
    @since               = '2018-01-01' # to be a parameter
    @until               = '2018-12-31' # to be a parameter
    @account_number      = account_number
    @company_rfc         = company_rfc
    @contalink_movements = get_contalink_movements(company_rfc)
    @bank_movements      = get_bank_account_movements(account_number)
    @deposits_cl         = calculate_deposits_cl(@contalink_movements)
    @withdrawals_cl      = calculate_withdrawals_cl(@contalink_movements)
    @deposits_bank       = calculate_deposits_bank(@bank_movements)
    @withdrawals_bank    = calculate_withdrawals_bank(@bank_movements)
  end

  def approves?
    @deposits_cl == @deposits_bank && @withdrawals_cl == @withdrawals_bank
  end

  def result
    {
      deposits_in_contalink: @deposits_cl,
      withdrawals_in_contalink: @withdrawals_cl,
      deposits_in_bank: @deposits_bank,
      withdrawals_bank: @withdrawals_bank,
      deposits_match_percentage: deposits_match_percentage,
      withdrawals_match_percentage: withdrawals_match_percentage
    }
  end

  def deposits_match_percentage
    (
      (
        @deposits_cl > @deposits_bank ?
          (@deposits_bank / @deposits_cl) :
          (@deposits_cl / @deposits_bank)
      ) * 100
    ).round(2)
  end

  def withdrawals_match_percentage
    (
      (
        @withdrawals_cl > @withdrawals_bank ?
          (@withdrawals_bank / @withdrawals_cl) :
          (@withdrawals_cl / @withdrawals_bank)
      ) * 100
    ).round(2)
  end

  private

  def get_contalink_movements(company_rfc)
    response = call_bank_web_service(
      ENV['CONTALINK_API_ENDPOINT'],
      {'Authorization' => authorization, 'Content-Type' => 'application/json'},
      {
        function_name: 'cl_get_status_accounts_in_period',
        function_param: {
          'empresa_rfc' => company_rfc,
          'desde' => '2018-01-01',
          'hasta' => '2018-12-31'
        }
      },
      'POST'
    )
    body = response_body(response)
    p body

    response.is_a?(Net::HTTPSuccess) ? body : []
  end

  def authorization
    'dd9379b4-6575-471a-91ef-1dbfffe59fa8 580cd5a8-bab1-49c6-9cb1-c3a576b65778'
  end

  def get_bank_account_movements(account_number)
    response = call_bank_web_service(
      ENV['ACCOUNT_MOVEMENTS_ENDPOINT'],
      bank_request_headers,
      {accountNumber: account_number, movementsNumber: 10}
    )
    body     = response_body(response)

    if response.is_a?(Net::HTTPSuccess)
      if !body['responseCodes'].nil? && body['responseCodes']['responseCode'] == '00'
        body['historicalMovements']['movements'].select{ |tr| tr['amount'] > 0 }
      else
        []
      end
    else
      []
    end
  end

  def calculate_deposits_cl(cl_movements)
    cl_movements.map{ |mv| Float(mv['deposito']) }.reduce(0, :+).round(2)
  end

  def calculate_withdrawals_cl(cl_movements)
    cl_movements.map{ |mv| Float(mv['retiro']) }.reduce(0, :+).round(2)
  end

  def calculate_deposits_bank(bank_movements)
    _since = Date.parse(@since)
    _until = Date.parse(@until)

    bank_movements.select{ |mv| mv['transactionType'] == 'C' }.select do |mv|
      mv_date = Date.strptime(mv['operationDate'], '%d/%m/%y')

      mv_date >= _since && mv_date <= _until
    end.map do |mv|
      Float(mv['amount'])
    end.reduce(0, :+).round(2)
  end

  def calculate_withdrawals_bank(bank_movements)
    _since = Date.parse(@since)
    _until = Date.parse(@until)

    bank_movements.select{ |mv| mv['transactionType'] == 'D' }.select do |mv|
      mv_date = Date.strptime(mv['operationDate'], '%d/%m/%y')

      mv_date >= _since && mv_date <= _until
    end.map do |mv|
      Float(mv['amount'])
    end.reduce(0, :+).round(2)
  end
end
