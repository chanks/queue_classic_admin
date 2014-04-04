require 'sinatra'
require 'queue_classic'

module QueueClassic
  class Admin < Sinatra::Base
    get '/:table_name?' do
      @tables = get_table_names
      table_name = (params[:table_name] || QC::TABLE_NAME).to_s
      halt(404, "Invalid table.") unless @tables.include?(table_name)

      @column_names = get_column_names(table_name)
      offset = (page_number - 1) * jobs_per_page
      order_by = %w(id not_before).find{|c| @column_names.include?(c)}

      if params[:q_name]
        @queue_classic_jobs = execute("SELECT * FROM #{table_name} WHERE q_name = $1 #{"ORDER BY #{order_by} DESC " if order_by} LIMIT $2 OFFSET $3", [params[:q_name], jobs_per_page, offset])
      else
        @queue_classic_jobs = execute("SELECT * FROM #{table_name} #{"ORDER BY #{order_by} DESC " if order_by} LIMIT $1 OFFSET $2", [jobs_per_page, offset])
      end

      @queue_counts = execute("SELECT q_name, count(*) FROM #{table_name} GROUP BY q_name")
      erb :index
    end

    post '/queue_classic_jobs/:id/destroy' do
      execute "DELETE FROM queue_classic_jobs WHERE id = $1", [params[:id]]
      redirect '/'
    end

    post '/queue_classic_jobs/:id/unlock' do
      execute "UPDATE queue_classic_jobs SET locked_at = NULL WHERE id = $1", [params[:id]]
      redirect '/'
    end

    post '/queue_classic_jobs/destroy_all' do
      execute "DELETE FROM queue_classic_jobs"
      redirect '/'
    end

    post '/queue_classic_jobs/unlock_all' do
      execute "UPDATE queue_classic_jobs SET locked_at = NULL WHERE locked_at < now() - '5 minutes'::interval"
      redirect '/'
    end

    helpers do
      def get_column_names(table_name)
        @_column_name_cache ||= {}

        unless @_column_name_cache[table_name]
          columns = execute("SELECT column_name FROM information_schema.columns WHERE table_name = $1", [table_name]);
          @_column_name_cache[table_name] = columns.map {|column| column.column_name }
        end

        @_column_name_cache[table_name]
      end

      def get_table_names
        unless @_table_name_cache
          tables = execute("SELECT table_name FROM information_schema.tables WHERE table_name ILIKE 'queue_classic%'");
          @_table_name_cache = tables.map {|table| table.table_name }
        end

        @_table_name_cache
      end

      def q_name_pill_class(name)
        if params[:q_name] == name
          "active"
        else
          ""
        end
      end

      def jobs_per_page
        (ENV["JOBS_PER_PAGE"] || 50).to_i
      end

      def execute(*args)
        QC.default_conn_adapter.connection.exec(*args).map{|h| OpenStruct.new(h)}
      end

      def page_number
        (params[:page] || 1).to_i
      end

      def previous_page?
        page_number > 1
      end

      def next_page?
        @queue_classic_jobs.count == jobs_per_page
      end
    end
  end
end
