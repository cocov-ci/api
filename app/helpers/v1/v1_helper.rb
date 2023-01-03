# frozen_string_literal: true

module V1
  module V1Helper
    def update_page_param(new_page)
      url = URI.parse(request.original_url)
      params = Rack::Utils.parse_nested_query url.query
      params["page"] = new_page
      url.query = params.to_param
      url.to_s
    end

    def paging_info(col)
      Jbuilder.new do |json|
        json.child! do
          json.prev_page update_page_param(col.prev_page) if col.prev_page
          json.next_page update_page_param(col.next_page) if col.next_page
          json.page col.current_page
          json.total_pages col.total_pages
        end
      end
    end
  end
end
