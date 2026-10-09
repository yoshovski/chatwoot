class Api::V1::Accounts::Captain::ScenariosController < Api::V1::Accounts::BaseController
  before_action -> { check_authorization(Captain::Scenario) }
  before_action :set_assistant
  before_action :set_scenario, only: [:show, :update, :destroy]

  def index
    @scenarios = assistant_scenarios
  end

  def show; end

  def create
    @scenario = assistant_scenarios.create!(scenario_params.merge(account: Current.account))
  end

  def update
    @scenario.update!(scenario_params)
  end

  def destroy
    @scenario.destroy
    head :no_content
  end

  def draft
    prompt = (params[:description] || params.dig(:scenario, :description)).to_s.strip
    if prompt.length < 10 || prompt.length > 2000
      return render json: { error: 'Description must be between 10 and 2,000 characters' }, status: :unprocessable_entity
    end

    result = Captain::Llm::ScenarioDraftService.new(
      assistant: @assistant,
      user_prompt: prompt
    ).perform

    if result
      render json: result
    else
      render json: { error: 'Unable to generate scenario draft. Please try again with more details.' }, status: :unprocessable_entity
    end
  end

  private

  def set_assistant
    @assistant = account_assistants.find(params[:assistant_id])
  end

  def account_assistants
    @account_assistants ||= Current.account.captain_assistants
  end

  def set_scenario
    @scenario = assistant_scenarios.find(params[:id])
  end

  def assistant_scenarios
    @assistant.scenarios
  end

  def scenario_params
    params.require(:scenario).permit(:title, :description, :instruction, :enabled, tools: [])
  end
end
