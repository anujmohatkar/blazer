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

  end
end
