module Spina
  module Admin
    class PageSelectOptionsController < AdminController
      
      def show
        @page = Page.find(params[:id])
      end
      
      def index
      end
      
      def search
        if params[:resource].present?
          @pages = Resource.find_by(name: params[:resource])&.pages
        end
        
        @pages ||= Page.all
        
        # Use FTS search if available, otherwise fallback to LIKE search
        if params[:search].present?
          search_options = {
            resource_id: params[:resource].present? ? Resource.find_by(name: params[:resource])&.id : nil,
            active_only: true
          }
          @pages = Spina::SearchService.search_pages(params[:search], search_options)
        end
        
        @pages = @pages.order(created_at: :desc).distinct.page(params[:page]).per(20)
        render :index
      end
      
    end
  end
end