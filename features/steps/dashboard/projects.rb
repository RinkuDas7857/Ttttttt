class Spinach::Features::DashboardProjects < Spinach::FeatureSteps
  include SharedAuthentication
  include SharedPaths
  include SharedProject

  step 'I should see projects list' do
    @user.authorized_projects.all.each do |project|
      expect(page).to have_link project.name_with_namespace
    end
  end
end
