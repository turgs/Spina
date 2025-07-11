module Spina
  module Admin
    class ResourceSelectOptionsController < AdminController

      def show
        @resource = Resource.find(params[:id])
      end

      def index
      end

      def search
        # Use FTS search if available, otherwise fallback to LIKE search
        if params[:search].present?
          @resources = Spina::SearchService.search_resources(params[:search])
        else
          @resources = Resource.all
        end
        
        @resources = @resources.order(created_at: :desc).distinct.page(params[:page]).per(20)
        render :index
      end

    end
  end
end
