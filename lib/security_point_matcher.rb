# todo: add doc
class SecurityPointMatcher
  include ExternalServicesMethods

  attr_reader :account_number, :company_rfc, :contalink_movements, :bank_movements
  attr_reader :connection

  def initialize(account_number, company_rfc)
    @since               = '2018-01-01' # to be a parameter
    @until               = '2018-12-31' # to be a parameter
    @account_number      = account_number
    @company_rfc         = company_rfc
    @connection          = build_connection
    @contalink_movements = get_contalink_movements(company_rfc)
    @bank_movements      = get_bank_account_movements(account_number)
    @deposits_cl         = calculate_deposits_cl(@contalink_movements)
    @withdrawals_cl      = calculate_withdrawals_cl(@contalink_movements)
    @deposits_bank       = calculate_deposits_bank(@bank_movements)
    @withdrawals_bank    = calculate_withdrawals_bank(@bank_movements)
    @connection.close()
  end

  def approves?
    @deposits_cl == @deposits_bank && @withdrawals_cl == @withdrawals_bank
  end

  def result
    {
      deposits_in_contalink: @deposits_cl,
      withdrawals_in_contalink: @withdrawals_cl,
      deposits_in_bank: @deposits_bank,
      withdrawals_bank: @withdrawals_bank
    }
  end

  private

  def build_connection
    new_connection({
      'host' => ENV['DB_HOST'],
      'database' => ENV['DB_NAME'],
      'username' => ENV['DB_USER'],
      'password' => ENV['DB_PASS']
    })
  end

  def get_contalink_movements(company_rfc)
    connection.exec(%{
      select
        *
      from status_accounts
      inner join status_account_groups
      on status_account_groups.id = status_accounts.status_account_group_id
      where status_account_groups.cuenta_empresa_id = (
        select
          id
        from cuenta_empresas
        where empresa_id in (
          select
            id
          from empresas where rfc = 'TEG080425R58'
        )
        order by created_at desc limit 1
      )
      and fecha >= '#{@since}' and fecha <= '#{@until}'
    }).map{ |row| row }
  end

  def get_bank_account_movements(account_number)
    response = call_bank_web_service(
      ENV['ACCOUNT_MOVEMENTS_ENDPOINT'],
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
