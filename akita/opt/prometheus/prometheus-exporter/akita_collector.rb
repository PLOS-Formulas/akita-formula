class AkitaCollector < PrometheusExporter::Server::CollectorBase

  def initialize
    @verified_users_cnt = PrometheusExporter::Metric::Counter.new('verified_users_count', 'Total # of verified accounts')
    @all_users_cnt = PrometheusExporter::Metric::Counter.new('all_users_count', 'Total # of accounts created (verified & unverified)')
    @mutex = Mutex.new
  end

  def process(str)
    obj = JSON.parse(str)
    @mutex.synchronize do
      if verified_cnt = obj["verified_users_count"]
        @verified_users_cnt.observe(verified_cnt)
      end

      if user_cnt = obj["all_users_count"]
        @all_users_cnt.observe(user_cnt)
      end
    end
  end

  def prometheus_metrics_text
    @mutex.synchronize do
      "#{@verified_users_cnt.to_prometheus_text}\n#{@all_users_cnt.to_prometheus_text}"
    end
  end
end
