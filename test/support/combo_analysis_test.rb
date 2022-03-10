require_relative "test_helper"

class ComboAnalysisTest < ActionDispatch::IntegrationTest
  def test_postgres
    run_query "SELECT 1 AS user_id, NOW() AS conversion_time /* combo analysis */", query_id: 1
    assert_match "1 combo", response.body
  end

  def test_mysql
    skip unless ENV["TEST_MYSQL"]

    run_query "SELECT 1 AS user_id, NOW() AS conversion_time /* combo analysis */", query_id: 1, data_source: "mysql"
    assert_match "1 combo", response.body
  end
end
