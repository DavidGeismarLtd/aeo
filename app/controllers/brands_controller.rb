# frozen_string_literal: true

# BrandsController handles CRUD operations for brands within workspaces
# All actions are scoped to the current workspace via acts_as_tenant
class BrandsController < ApplicationController
  skip_before_action :set_current_tenant
  before_action :authenticate_user!
  before_action :set_workspace
  before_action :set_brand, only: [ :show, :edit, :update, :destroy ]

  # GET /:workspace_slug/brands
  def index
    @brands = @workspace.brands.order(name: :asc)

    # Search functionality
    if params[:search].present?
      @brands = @brands.where("name ILIKE ?", "%#{params[:search]}%")
    end

    # Pagination (20 per page)
    @brands = @brands.page(params[:page]).per(20)
  end

  # GET /:workspace_slug/brands/:id
  def show
    # @brand set by before_action
  end

  # GET /:workspace_slug/brands/new
  def new
    @brand = @workspace.brands.build
  end

  # POST /:workspace_slug/brands
  def create
    @brand = @workspace.brands.build(brand_params)

    if @brand.save
      redirect_to workspace_brand_path(@workspace, @brand),
                  notice: "Brand was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /:workspace_slug/brands/:id/edit
  def edit
    # @brand set by before_action
  end

  # PATCH/PUT /:workspace_slug/brands/:id
  def update
    if @brand.update(brand_params)
      redirect_to workspace_brand_path(@workspace, @brand),
                  notice: "Brand was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /:workspace_slug/brands/:id
  def destroy
    @brand.destroy
    redirect_to workspace_brands_path(@workspace),
                notice: "Brand was successfully deleted."
  end

  private

  def set_workspace
    @workspace = current_user.workspaces.find_by!(slug: params[:workspace_slug])
    # Set as current tenant for acts_as_tenant
    ActsAsTenant.current_tenant = @workspace
  rescue ActiveRecord::RecordNotFound
    redirect_to workspaces_path, alert: "Workspace not found or you don't have access."
  end

  def set_brand
    @brand = @workspace.brands.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to workspace_brands_path(@workspace), alert: "Brand not found."
  end

  def brand_params
    params.require(:brand).permit(:name, :description, :domain)
  end
end
