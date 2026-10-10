class SuperAdmin::DifyWorkspacesController < SuperAdmin::ApplicationController
  def show
    @workspace = DifyWorkspace.current || DifyWorkspace.new(id: 1)
  end

  def update
    @workspace = DifyWorkspace.find_or_create_by!(id: 1)
    @workspace.with_lock do
      values = params.require(:dify_workspace).permit(:enabled, :knowledge_api_key, *DifyWorkspace::CONFIGURATION_FIELDS)
      values.delete(:knowledge_api_key) if values[:knowledge_api_key].blank?
      @workspace.assign_attributes(values)
      unless @workspace.valid?
        render :show, status: :unprocessable_entity
        return
      end

      Dify::WorkspaceSync.call(@workspace, actor: current_super_admin)
      @workspace.save!
    end
    redirect_to super_admin_dify_workspace_path, notice: I18n.t('super_admin.dify_workspace.saved')
  rescue Dify::WorkspaceSync::Error
    @workspace.errors.add(:base, I18n.t('super_admin.dify_workspace.sync_failed'))
    render :show, status: :unprocessable_entity
  end
end
