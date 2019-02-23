# todo: add doc
class BankAccountExistanceValidator
  include ExternalServicesMethods
  attr_reader :account_number

  def initialize(account_number)
    @account_number = account_number
  end

  def exists?
    response = call_bank_web_service(ENV['ACCOUNT_EXISTANCE_ENDPOINT'], {accountNumber: account_number})
    body     = response_body(response)

    if response.is_a?(Net::HTTPSuccess)
      !body['responseCodes'].nil? && body['responseCodes']['responseCode'] == '00'
    else
      false
    end
  end
end
