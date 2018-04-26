local ReportsBatch = require 'apicast.policy.3scale_batcher.reports_batch'

describe('reports batch', function()
  local reports_with_user_key = {
    { user_key = 'uk1', metric = 'm1', value = 1 },
    { user_key = 'uk1', metric = 'm2', value = 1 },
    { user_key = 'uk2', metric = 'm2', value = 2 }
  }

  local reports_with_app_id = {
    { app_id = 'id1', metric = 'm1', value = 1 },
    { app_id = 'id1', metric = 'm2', value = 1 },
    { app_id = 'id2', metric = 'm2', value = 2 }
  }

  local reports_with_access_token = {
    { access_token = 't1', metric = 'm1', value = 1 },
    { access_token = 't1', metric = 'm2', value = 1 },
    { access_token = 't2', metric = 'm2', value = 2 }
  }

  describe('with reports with user keys', function()
    it('groups them correctly', function()
      local batch = ReportsBatch.new('s1', reports_with_user_key)

      assert.equals('s1', batch.service_id)
      assert.equals('user_key', batch.credentials_type)
      assert.same({ uk1 = { m1 = 1, m2 = 1 }, uk2 = { m2 = 2 } }, batch.reports)
    end)
  end)

  describe('with reports with app IDs', function()
    it('groups them correctly', function()
      local batch = ReportsBatch.new('s1', reports_with_app_id)

      assert.equals('s1', batch.service_id)
      assert.equals('app_id', batch.credentials_type)
      assert.same({ id1 = { m1 = 1, m2 = 1 }, id2 = { m2 = 2 } }, batch.reports)
    end)
  end)

  describe('with reports with access tokens', function()
    it('groups them correctly', function()
      local batch = ReportsBatch.new('s1', reports_with_access_token)

      assert.equals('s1', batch.service_id)
      assert.equals('access_token', batch.credentials_type)
      assert.same({ t1 = { m1 = 1, m2 = 1 }, t2 = { m2 = 2 } }, batch.reports)
    end)
  end)
end)
