require 'json'
require 'net/http'
require './lib/external_services_methods.rb'
require './lib/bank_account_existance_validator.rb'
require './lib/security_point_matcher.rb'

def lambda_handler(event:, context:)
  username               = '*'
  password               = '*'
  account_number         = event['body-json']['account_number'] || '4099856726'
  company_rfc            = event['body-json']['empresa_rfc']
  existance_validator    = BankAccountExistanceValidator.new(account_number)
  security_point_matcher = SecurityPointMatcher.new(account_number, company_rfc)

  if existance_validator.exists?
    result_response = {
      account_existance: true,
      security_point_approved: security_point_matcher.approves?,
      security_point_result: security_point_matcher.result
    }
  else
    result_response = {
      account_existance: false,
      security_point_approved: false,
      security_point_result: nil
    }
  end

  {
    statusCode: 200,
    body: result_response
  }
end
