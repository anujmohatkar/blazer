require 'httparty'
module Blazer
  class Query < Record
    belongs_to :creator, optional: true, class_name: Blazer.user_class.to_s if Blazer.user_class
    has_many :checks, dependent: :destroy
    has_many :dashboard_queries, dependent: :destroy
    has_many :dashboards, through: :dashboard_queries
    has_many :audits

    validates :statement, presence: true

    scope :active, -> { column_names.include?("status") ? where(status: ["active", nil]) : all }
    scope :named, -> { where.not(name: "") }

    def to_param
      [id, name].compact.join("-").gsub("'", "").parameterize
    end

    def friendly_name
      name.to_s.sub(/\A[#\*]/, "").gsub(/\[.+\]/, "").strip
    end

    def viewable?(user)
      if Blazer.query_viewable
        Blazer.query_viewable.call(self, user)
      else
        true
      end
    end

    def editable?(user)
      editable = !persisted? || (name.present? && name.first != "*" && name.first != "#") || user == try(:creator)
      editable &&= viewable?(user)
      editable &&= Blazer.query_editable.call(self, user) if Blazer.query_editable
      editable
    end

    def variables
      variables = Blazer.extract_vars(statement)
      variables += ["cohort_period"] if cohort_analysis?
      variables += ["combo_period"] if combo_analysis?
      variables
    end

    def cohort_analysis?
      /\/\*\s*cohort analysis\s*\*\//i.match?(statement)
    end

    def combo_analysis?
      /\/\*\s*combo analysis\s*\*\//i.match?(statement)
    end

    #hc_combos methods

    def hc_x_axis(rows)
      @hc_x_axis = rows.map { |r| r[0] }  
    end
    
    def combo_chart_test(rows)
      if rows[0].length > 2 && rows[0][1..-1].all? { |e| e.is_a? Numeric } == true
        return true
      else
        return false
      end
    end

    def hc_y_axis(columns)
      y_axis = Array.new
      col_len = (columns.length - 1).to_i
      x = 1
      (col_len - 1).times do
        until x >= (col_len / 2)
          data = {
            'title' => {
              'text' => columns[x]
            } 
          }
          y_axis << data
          x += 1 
        end
        data = {
          'title' => {
            'text' => columns[x]
          },
          'opposite' => true
        }
        y_axis << data
        x += 1
      end
      @hc_y_axis = y_axis.to_json
    end

    def hc_y_axis_data(rows, columns)
      hc_row_array ||= rows.dup
      # Index variables
      x = 0
      y = 1
      # Index columns
      hcyl = Array.new
      # Column code
      (columns.length - 2).times do
        arr = Array.new 
        hc_row_array.each do |row| 
          arr << row[y].to_f
        end 
        arr
        args = {
          'name' => columns[y].to_s,
          'type' => "column",
          'data' => arr
        }
        hcyl << args
        x += 1
        y += 1
      end
      # Spline code
      spline_arr = Array.new
      hc_row_array.each do |row|
        spline_arr << row.last.to_f
      end
      spline = {
        'name' => columns.last.to_s,
        'type' => "spline",
        'data' => spline_arr
      }
      hcyl << spline
      @hc_y_axis_data = hcyl.to_json
    end

    def hc_y_axis_data_x(hc_x_axis, rows, columns)
      hc_row_array ||= rows.first(15).dup
      # Index variables
      x = 0
      y = 1
      y_axis = 0
      # Index columns
      hcyl = Array.new
      # Column code
      (columns.length - 1).times do
        if (columns.length / 2) > x
          p x 
          arr = Array.new 
          hc_row_array.each do |row| 
            arr << row[y].to_f
          end 
          arr
          args = {
            'name' => columns[y].to_s,
            'type' => "column",
            'data' => arr
          }
          args.store('yAxis', y_axis) if x != 0

          hcyl << args
          x += 1
          y += 1
          y_axis += 1
        else
          arr = Array.new 
          hc_row_array.each do |row| 
            arr << row[y].to_f
          end 
          arr
          args = {
            'name' => columns[y].to_s,
            'type' => "spline",
            'yAxis' => y_axis,
            'data' => arr
          }
          hcyl << args
          
          x += 1
          y += 1
          y_axis += 1
          break if y == columns.length
        end
      end
      @hc_y_axis_data = hcyl.to_json
    end



    # modified methods by maulik
    # x = 0 not used so removed
    # y = 0 removed, times with index(1) always return from 1, 2, n. so we can use it.
    def hc_y_axis_data_m(rows, columns)
      hc_row_array ||= rows.dup
      # Index columns
      hcyl = []
      # Column code
      (columns.length - 2).times.with_index(1) do |cl, i|
        arr = hc_row_array.map { |row| row[i].to_f }
        args = {
          'name' => columns[i].to_s,
          'type' => "column",
          'data' => arr
        }
        hcyl << args
      end
      # Spline code
      spline_arr = hc_row_array.map { |row| row.last.to_f }
      spline = {
        'name' => columns.last.to_s,
        'type' => "spline",
        'data' => spline_arr
      }
      hcyl << spline
      @hc_y_axis_data = hcyl.to_json
    end
    def hc_y_axis_data_mx(hc_x_axis, rows, columns)
      hc_row_array ||= rows.first(15).dup
      # Index columns
      hcyl = []
      # Column code
      (columns.length - 1).times.with_index(1) do |cl, i|
        if (columns.length / 2) > cl
          arr = hc_row_array.map { |row| row[i].to_f }
          args = {
            'name' => columns[i].to_s,
            'type' => "column",
            'data' => arr
          }
          args.store('yAxis', cl) if cl != 0

          hcyl << args
        else
          arr = hc_row_array.map { |row| row[i].to_f }
          args = {
            'name' => columns[i].to_s,
            'type' => "spline",
            'yAxis' => cl,
            'data' => arr
          }
          hcyl << args
          break if i == columns.length
        end
      end
      @hc_y_axis_data = hcyl.to_json
    end



    # box plot test methods
    def box_test(rows, modified_rows)
      if modified_rows[0].length >= 5 && rows[0].all? { |e| e.is_a? Numeric } == true
        return true
      else
        return false
      end 
    end
    
    # box plot methods
    def hcbp_raw_arrays(rows, columns)
      hcbp = []
      (columns.length).times do |i|
        hcbp << rows.map { |row| row[i].to_f }
      end
      @hcbp_raw_arrays = hcbp
    end

    def hcbp_data_arrays(raw_arrays)
      hcbp = []
      raw_arrays.each do |f|
        p "----------------------------"
        x = []
        q1_2 = []
        q2_3 = []
        i = f.sort
        p i
        x << i.first
        p "lower bound: #{i.first}" 
        if i.length % 2 == 0
          m2 = i[(i.length / 2)]
          m1 = i[(i.length / 2) - 1]
          median_index = ((i.length / 2) -1)
          q1_median = (m1 + m2) / 2
        else
          q1_median = i[(i.length / 2 - 1)]
          median_index = (i.length / 2 - 1)
        end
        p "----------------------------"
        p "median index: #{median_index}"
        p "Median : #{q1_median}"
        i[0..(median_index-1)].each do |x|
          q1_2 << x
        end
        i[(median_index+1)..(i.length-1)].each do |x|
          q2_3 << x
        end
        p "----------------------------"
        p "Q1 ot Q2 : #{q1_2}"
        p "----------------------------"
        p "Q2 ot Q3 : #{q2_3}"
        p "----------------------------"
        if q1_2.length % 2 == 0
          qm2 = q1_2[(q1_2.length / 2)]
          qm1 = q1_2[(q1_2.length / 2) - 1]
          q1 = (qm1 + qm2) / 2
        else
          q1 = q1_2[(q1_2.length / 2) - 1]
        end
        x << q1
        x << q1_median
        if q2_3.length % 2 == 0
          qm3 = q2_3[(q2_3.length / 2)]
          qm4 = q2_3[(q2_3.length / 2) - 1]
          q3 = (qm3 + qm4) / 2
        else
          q3 = q2_3[(q2_3.length / 2) - 1]
        end
        x << q3
        x << i.last
        p x
        p "----------------------------"
        hcbp << x
      end
      @hcbp_data_arrays = hcbp
    end
  
    # bubble chart methods
    # hcbc = highcharts bubble chart
    # bubble chart method to get data for plotting bubble chart
    # sample data : [91, "Novelty Measure", 3.0, 60.0, "column_0"], [91, "Novelty Measure", 2.5, 50.0, "column_1"]
    # def bubble_data(rows, columns)
    #  bubble_array = []
    #  x_cord_index = 0
    #  y_cord_index = 1
    #  if rows.size.even? == true
    #    (rows.length /2).times do
    #      bubble_item = {
    #        'x' => row[x_cord_index][2].to_f,
    #        'y' => row[y_cord_index][2].to_f,
    #        'z' => 0,
    #        'name' => row[0][0][0..1].to_s,
    #        "#{columns[1][1]}" => row[0][1].to_s
    #      }
    #      bubble_array << bubble_item
    #      x_cord_index += 2
    #      y_cord_index += 2
    #    end
    #    @bubble_data = bubble_array.to_json
    #  else
    #    @bubble_data = "Invalid format of inputs"
    #  end
    # end

    # bubble chart method for x-axis reference line value
    def hcbc_x_axis(rows)
      @hcbc_x_axis = ((rows[1].sort.last + rows[1].sort.first) / 2).round(2)
    end
    
     # bubble chart method for y-axis reference line value
    def hcbc_y_axis(rows)
      @hcbc_x_axis = ((rows[2].sort.last + rows[2].sort.first) / 2).round(2)
    end




    ######################
    # methods for linked bubble heatmap (lbh)
    ######################

    # method to test if the query has enough columns to plot linked bubble heatmap
    def lbh_test(columns)
      if (columns.length % 2 == 1) && columns.length >= 5
        @lbh_test = true
      else 
        @lbh_test = false
      end
    end

    # method to get data for plotting linked bubble heatmap
    def lbh_data(rows, columns)
      lbh_array = [] # array to store data for plotting linked bubble heatmap

      # code to get data for plotting the bubbles b_array means bubble array to store the hash in the array.
      # the individual hash here plots a bubble on the chart.
      b_array = []
      rows.each.with_index do |row, i|
        j = 1
        ((columns.length - 1) / 2).times do
          if row[j] != nil && row[j+1] != nil
            hcbc_item = {
              'x' => row[j].to_f,
              'y' => row[j+1].to_f,
              'name' => row[0][0..1].to_s,
              "#{columns[0]}" => row[0].to_s
            }
            j += 2
            b_array << hcbc_item
          end
        end
      end
      bubble_hash = {}
      bubble_hash[:data] = b_array
      lbh_array << bubble_hash

      # code to get data for plotting the lines connecting the bubbles
      # each hash makes a line on the chart.
      rows.each.with_index do |row , i|
        lbh_hash_item = Hash.new
        j = 1
        line_array = []
        ((columns.length - 1) / 2).times do
          if row[j] != nil && row[j+1] != nil
            lbh_item = {
              'x' => rows[i][j].to_f,
              'y' => rows[i][(j + 1)].to_f  
            }

            line_array << lbh_item
            j += 2
          end
        end
        lbh_hash_item[:type] = 'line'
        lbh_hash_item['data'] = line_array
        lbh_array << lbh_hash_item

      end
      # associating the array in json format for highcharts
      @lbh_data = lbh_array.to_json
    end

    # Methods for line bubble heatmap data (new query format)
    # input ([[133, "Chamber Italian", 117, 0.1499e2], [384, "Grosse Wonderful", 49, 0.1999e2], [8, "Airport Pollock", 54, 0.1599e2], [98, "Bright Encounters", 73, 0.1299e2]])
    def heatmap_data(rows) # pass @rows and @colummns here.
      heatmap_array = []

      # code to get data for plotting the bubbles b_array means bubble array to store the hash in the array.
      # the individual hash here plots a bubble on the chart.
      b_array = []
      rows.each.with_index do |row, i|
        b_array << {
          'x' => rows[i][2].to_f, # x-coordinate of bubble
          'y' => rows[i][3].to_f, # y-coordinate of bubble
          'z' => 1, # the size of the bubble, keeping it 1 , felt 0 will will be just nothing there, can be changed
          'name' => rows[i][0].to_s, # name that will be rendered on the bubble, here, acc. to query, it will be id.
          'category' => rows[i][1].to_s
        }
      end
      bubble_hash = {}
      bubble_hash[:data] = b_array
      heatmap_array << bubble_hash
      # the above bubble hash will contain everything to render all the bubbles


      # code to get data for plotting the lines connecting the bubbles
      # each hash makes a line on the chart.
      line_row_index = 0
      (rows.length / 2).times do |i| # since 2 rows make 2 bubbles and make one line
        line_hash_item = Hash.new
        line_array = [] # the array that will contain the hashes of individual point of the line.
          line_item = {
            'x' => rows[line_row_index][2].to_f,
            'y' => rows[line_row_index][3].to_f
          }
          line_array << line_item
          line_item_2 = {
            'x' => rows[line_row_index + 1][2].to_f,
            'y' => rows[line_row_index + 1][3].to_f
          }
          line_array << line_item_2
          line_hash_item[:type] = 'line' # to specify that this is a line that we want to plot , we didn't do this with bubble because the chart type in the initial config is bubble.
          line_hash_item['data'] = line_array
          heatmap_array << line_hash_item
          line_row_index += 2 # increasing index of row by 2 because one line requires 2 rows .
        end
      # converting the array to json format so it can be used in highchart.
      @heatmap_data = heatmap_array.to_json 
    end


    # method of linked bubble heatmap for x-axis reference line value
    def lbh_x_axis(rows)
      #middle value = ((max value in array + min value in the array) / 2).round(2)
      x_axis_all_values = []
      rows.each do |row|
        x_axis_all_values << row[2].to_f
      end
      p x_axis_all_values
      @lbh_x_axis = ((x_axis_all_values.sort.last + x_axis_all_values.sort.first) / 2).round(2)
    end

    # method of linked bubble heatmap for y-axis reference line value
    def lbh_y_axis(rows)
      #middle value = ((max value in array + min value in the array) / 2).round(2)
      y_axis_all_values = []
      rows.each do |row|
        y_axis_all_values << row[3].to_f
      end
      p y_axis_all_values
      @lbh_y_axis = ((y_axis_all_values.sort.last + y_axis_all_values.sort.first) / 2).round(2)
    end

    # method to convert the raw arrays into arrays of each column. into an array of arrays.
    # only the numeric arrays, no string, so thats why it starts at index = 1
    def lbh_raw_data(rows, columns)
      index = 1
      array = []
      (columns.length-1).times do
        array << rows.map { |row| row[index].to_f }
        index += 1
      end
      @lbh_raw_data = array
    end

    def email_list(rows)
      array = []
      rows.each do |row|
        array << row.all
      end
      @email_list = array
    end
    # 
    # methods to convert the query result to an array

    def email_list(rows)
      email_list = []
      rows.each do |row|
        email_list << row[0]
      end
      @email_list = email_list
    end
    
    # method to make an api request 
    def api_call(query, rows, columns)
      if query.api_auth_key.empty? == true 
        response = HTTParty.post(query.api_endpoint, body: {"input": rows.to_json, "output": columns.to_json, "product": {"input": rows.to_json,"output": columns.to_json}}) # Please modify the api json body to your needs
      else
        response = HTTParty.post(query.api_endpoint, body: {"input": rows.to_json, "output": columns.to_json, "product": {"input": rows.to_json,"output": columns.to_json}}, headers: {"Authorization" => query.api_auth_key}) # Please modify the api json body to your needs
      end

      api_response = JSON.parse(response.body)
      # below is the if-else loop to check the response from the api and its type
      if api_response["result"] == "error" # for error response
        p 'error on result response'
        @api_call = [ 'error', "Error: #{api_response["error"]}"]

      elsif api_response["result"] == 'image' # for image response
        p 'image_url'
        @api_call = [ 'image', api_response["image_url"]]

      elsif api_response["result"] == 'table' # for table response
        p 'image_url nil'
        @api_call = ['table', api_response["columns"], api_response["rows"]]
      elsif api_response['result'] == 'chart' # for chart response
        p 'chart'
        @api_call = ['chart', api_response["chart_type"], api_response["rows"], api_response["columns"]]
      end
    end

    def api_raw_response(response)
      if response["rows"].nil? || response["rows"].empty?
        @api_call_2 = "No output"
      else
        @api_call_2 = response["rows"]
      end
    end

    def api_image(response)
      if response["image_url"].nil? || response["image_url"].empty?
        @api_image = false
      else
        @api_image = response["image_url"]
      end
    end
    
    # Method for gauge data
    # input will be @rows array 
    # @rows=[[3.1, 62.0]]
    def guage_value(rows)
      @guage_value = [rows[0][1]]
    end
    # output here should be: [65.0]
    def column3_test(rows)
      if rows[0].length >= 3
        return true
      else
        return false
      end
    end
    # Method for world map ranges chart
    def world_map_data(rows)
      world_map_array = []
      rows.each do |row|
        world_map_array << {
          'code' => row[0],
          'name' => row[1],
          'value' => row[2]
        }
      end
      @world_map_data = world_map_array.to_json
    end

    def world_map_range(rows)
      world_map_range = []
      rows.each do |row|
        world_map_range << row[2]
      end
      @world_map_range = world_map_range
    end

    def scatter_data(rows)
      scatter_array = Array.new
      scatter_cat1 = Hash.new
      cat1_data = Array.new
      cat1_index = 0
      (rows.length / 2).times do
        cat1_data <<  [rows[cat1_index][1].to_f, rows[cat1_index][2].to_f]
        cat1_index += 2
      end
      scatter_cat1['name'] = 'category 1'
      scatter_cat1['color'] = 'rgba(223, 83, 83, .5)'
      scatter_cat1['data'] = cat1_data
      scatter_array << scatter_cat1

      scatter_cat2 = Hash.new
      cat2_data = Array.new
      cat2_index = 1
      (rows.length / 2).times do
        cat2_data <<  [rows[cat2_index][1].to_f, rows[cat2_index][2].to_f]
        p 'runned'
        cat2_index += 2
      end
      scatter_cat2['name'] = 'category 2'
      scatter_cat2['color'] = 'rgba(119, 152, 191, .5)'
      scatter_cat2['data'] = cat2_data
      scatter_array << scatter_cat2

      @scatter_data = scatter_array.to_json
    end



    def scatter_range(rows)
      
    end

    # Method for NPS chart ranges
    def nps_range(payload)
      nps_hash = Hash.new
      payload_data = JSON.parse(payload)
      p payload_data['ranges']
      nps_range = []
      payload_data['ranges'].each do |range|
        range_hash = {
          'from' => range['from'],
          'to' => range['to'],
          'thickness' => '50%',
          'color' => range['color']
        }
        nps_range << range_hash
      end
      nps_hash['min'] = payload_data['min']
      nps_hash['max'] = payload_data['max']
      nps_hash['plotBands'] = nps_range
      nps_hash['tickWidth'] = 0
      nps_hash['minorTickWidth'] = 0
      nps_hash['labels'] = { 'y' => 10}
      @nps_range = nps_hash.to_json
    end

    # Method to divide the array into ranges equally
    # [{
    #   to: 3
    #   }, {
    #       from: 3,
    #       to: 10
    #   }, {
    #       from: 10,
    #       to: 30
    #   }, {
    #       from: 30,
    #       to: 100
    #   }, {
    #       from: 100,
    #       to: 300
    #   }, {
    #       from: 300,
    #       to: 1000
    #   }, {
    #       from: 1000
    #   }]
    def world_map_ranges(rows, range_amount)
      data = []
      rows.each do |row|
        data << row[2].to_i
      end
      data.sort!
      p data
      index = 0
      ranges = Array.new
      data_length = data.length
      data_difference = data_length/range_amount
      (range_amount - 1).times do |i|
        if index == 0
          range_start = {
            'to' => data_difference
          }
          p range_start
          ranges << range_start
          index += data_difference
        else 
          if data_length > (index + data_difference)
            range = {
              'from' => index,
              'to' => (index + data_difference)
            }
            p range
            ranges << range
            index += data_difference
            p "range: #{index}"   
          end
        end
      end
      range = {
        'from' => index
      }
      ranges << range
      p index
      @world_map_ranges = ranges.to_json
    end

    # Expected Query for podcast
    # SELECT * FROM podcasts
    # or
    # SELECT title, summary, transcript, audio_url, prublished_time, audio_s3_location, audio_type, speaker_names, transcript_entities, source_feed FROM podcasts
    def podcasts(rows, columns)
      parse = Blazer::Podcard.new(rows, columns)
      @podcasts = parse.array
    end

    
    def heatmap(rows)
      # get all distinct values of 1st column
      x_row = rows.map { |row| row[0] }.uniq
      # get all distinct values of 2nd column
      y_row = rows.map { |row| row[1] }.uniq
      data = Array.new
      # create a 2d array that takes the values of the 1st and 2nd column and the 3rd column as the value

      x_row.each do |x|
        y_row.each do |y|
          
          #binding.pry
          f = rows.select { |row| row[0] == x && row[1] == y }
          if f.length > 0
            z = f[0][2]
          else
            z = 0
          end
          # puts index +1 for x and y 
          if z != 0
            data << [x_row.index(x), y_row.index(y), z]
          end
        end
      end
      @heatmap = data
    end

    def heatmap_x(rows)
      rows.map { |row| row[0] }.uniq
    end

    def heatmap_y(rows)
      rows.map { |row| row[1] }.uniq
    end

    def speedometer(rows)
      @speedometer = rows[0][0]
    end
    #"circle", "square", "diamond", "triangle" and "triangle-down" are the possible types of markers.
    def scatter2_data(rows)
      marker = ['circle', 'square', 'diamond', 'triangle', 'triangle-down']
      rows_types = rows.map { |row| row[0] }.uniq
      marker_index = 0
      if rows_types.length > 1 && rows_types.length < 6
        data = Array.new
        rows_types.each do |type|
          type_hash = Hash.new
          type_hash['name'] = type[0].to_s
          type_hash['id'] = type[0].to_s
          type_hash['marker'] = { 'symbol' => marker[marker_index] }
          type_data = Array.new
          rows.each do |row|
            if row[0] == type
              type_data << [row[1].to_f, row[2].to_f]
            end
          end
          type_hash['data'] = type_data
          data << type_hash
          marker_index += 1
        end
      else
        data = 'error: only 1 to 5 types of categories are allowed'
      end
      return data
    end

    # Given method converts the data into the format required by the highcharts network graph
    # IT takes the first 2 columns of the data and converts it into an array of arrays, where each array is a connection between 2 nodes
    # Example:
    # [
    #   ['A', 'B'],
    #   ['A', 'C'],
    #   ['B', 'D'],
    #   ['C', 'D']
    # ] 
    def network_graph(rows)
      data = Array.new
      rows.each do |row|
        data << [row[0], row[1]]
      end
      return data
    end

    def radar_data(rows)
 
    end
  end
end
