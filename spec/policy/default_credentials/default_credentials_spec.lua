local ipairs = ipairs

local DefaultCredentialsPolicy = require('apicast.policy.default_credentials')

describe('Default credentials policy', function()
  local policy_user_key = 'policy_uk'
  local policy_app_id = 'policy_ai'
  local policy_app_key = 'policy_ak'
  local request_user_key = 'req_uk'
  local request_app_id = 'req_ai'
  local request_app_key = 'req_ak'

  local function policy_with_default_user_key()
    return DefaultCredentialsPolicy.new(
      { auth_type = 'user_key', user_key = policy_user_key }
    )
  end

  local function policy_with_default_app_id_and_key()
    return DefaultCredentialsPolicy.new(
      {
        auth_type = 'app_id_and_app_key',
        app_id = policy_app_id,
        app_key = policy_app_key
      }
    )
  end

  local function service_with_user_key_in_req()
    return {
      backend_version = '1',
      extract_credentials = function()
        return { request_user_key, user_key = request_user_key }
      end
    }
  end

  local function service_without_user_key_in_req()
    return {
      backend_version = '1',
      extract_credentials = function() return { } end
    }
  end

  local function service_with_app_id_and_key_in_req()
    return {
      backend_version = '2',
      extract_credentials = function()
        return { request_app_id, request_app_key,
                 app_id = request_app_id, app_key = request_app_key }
      end
    }
  end

  local function service_with_app_id_in_req()
    return {
      backend_version = '2',
      extract_credentials = function()
        return { request_app_id, app_id = request_app_id }
      end
    }
  end

  local function service_with_app_key_in_req()
    return {
      backend_version = '2',
      extract_credentials = function()
        return { request_app_key, app_key = request_app_key }
      end
    }
  end

  local function service_without_app_id_nor_key_in_req()
    return {
      backend_version = '2',
      extract_credentials = function() return {} end
    }
  end

  describe('.rewrite', function()
    describe('when the service in the context has backend_version = 1', function()
      describe('and the request includes a user key', function()
        describe('and there is a default user key defined', function()
          it('does not set any credentials in the context', function()
            local context = { service = service_with_user_key_in_req() }

            policy_with_default_user_key():rewrite(context)

            assert.is_nil(context.extracted_credentials)
          end)
        end)

        describe('and there is not a default user key defined', function()
          it('does not set any credentials in the context', function()
            local context = { service = service_with_user_key_in_req() }

            policy_with_default_app_id_and_key():rewrite(context)

            assert.is_nil(context.extracted_credentials)
          end)
        end)
      end)

      describe('and the request does not include a user key', function()
        describe('and there is a default user key defined', function()
          it('sets the default user key in the context', function()
            local context = { service = service_without_user_key_in_req() }

            policy_with_default_user_key():rewrite(context)

            assert.same({ policy_user_key, user_key = policy_user_key },
                        context.extracted_credentials)
          end)
        end)

        describe('and there is not a default user key defined', function()
          it('does not set any credentials in the context', function()
            local context = { service = service_without_user_key_in_req() }

            policy_with_default_app_id_and_key():rewrite(context)

            assert.is_nil(context.extracted_credentials)
          end)
        end)
      end)
    end)

    describe('when the service in the context has backend_version = 2', function()
      describe('and the request includes an app id and an app key', function()
        describe('and there is a default app id and key defined', function()
          it('does not set any credentials in the context', function()
            local context = { service = service_with_app_id_and_key_in_req() }

            policy_with_default_app_id_and_key():rewrite(context)

            assert.is_nil(context.extracted_credentials)
          end)
        end)

        describe('and there is not a default app and key defined', function()
          it('does not set any credentials in the context', function()
            local context = { service = service_with_app_id_and_key_in_req() }

            policy_with_default_user_key():rewrite(context)

            assert.is_nil(context.extracted_credentials)
          end)
        end)
      end)

      describe('and the request includes an app id but no app key', function()
        describe('and there is a default app id and key defined', function()
          it('does not set any credentials in the context', function()
            local context = { service = service_with_app_id_in_req() }

            policy_with_default_app_id_and_key():rewrite(context)

            assert.is_nil(context.extracted_credentials)
          end)
        end)

        describe('and there is not a default app and key defined', function()
          it('does not set any credentials in the context', function()
            local context = { service = service_with_app_id_in_req() }

            policy_with_default_user_key():rewrite(context)

            assert.is_nil(context.extracted_credentials)
          end)
        end)
      end)

      describe('and the request includes an app key but not an app id', function()
        describe('and there is a default app id and key defined', function()
          it('does not set any credentials in the context', function()
            local context = { service = service_with_app_key_in_req() }

            policy_with_default_app_id_and_key():rewrite(context)

            assert.is_nil(context.extracted_credentials)
          end)
        end)

        describe('and there is not a default app and key defined', function()
          it('does not set any credentials in the context', function()
            local context = { service = service_with_app_key_in_req() }

            policy_with_default_user_key():rewrite(context)

            assert.is_nil(context.extracted_credentials)
          end)
        end)
      end)

      describe('and the request does not include an app key nor an app id', function()
        describe('and there is a default app id and key defined', function()
          it('sets the app and key in the context', function()
            local context = { service = service_without_app_id_nor_key_in_req() }

            policy_with_default_app_id_and_key():rewrite(context)

            assert.same(
              { policy_app_id, policy_app_key,
                app_id = policy_app_id, app_key = policy_app_key },
              context.extracted_credentials
            )
          end)
        end)

        describe('and there is not a default app and key defined', function()
          it('does not set any credentials in the context', function()
            local context = { service = service_without_app_id_nor_key_in_req() }

            policy_with_default_user_key():rewrite(context)

            assert.is_nil(context.extracted_credentials)
          end)
        end)
      end)
    end)

    describe('when the service in the context has backend_version != 1 and != 2', function()
      it('does not set any credentials in the context', function()
        local context = { service = { backend_version = 'oauth' } }

        local policies = {
          policy_with_default_user_key(),
          policy_with_default_app_id_and_key()
        }

        for _, policy in ipairs(policies) do
          policy:rewrite(context)
          assert.is_nil(context.extracted_credentials)
        end
      end)
    end)
  end)
end)
