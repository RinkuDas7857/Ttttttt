class Spinach::Features::ProfileGroup < Spinach::FeatureSteps
  include SharedAuthentication
  include SharedGroup
  include SharedPaths
  include SharedUser

  # Leave

  step 'I click on the "Leave" button for group "Owned"' do
    find(:css, 'li', text: "Owner").find(:css, 'i.fa.fa-sign-out').click
    # poltergeist always confirms popups.
  end

  step 'I click on the "Leave" button for group "Guest"' do
    find(:css, 'li', text: "Guest").find(:css, 'i.fa.fa-sign-out').click
    # poltergeist always confirms popups.
  end

  step 'I should not see the "Leave" button for group "Owned"' do
    expect(find(:css, 'li', text: "Owner")).not_to have_selector(:css, 'i.fa.fa-sign-out')
    # poltergeist always confirms popups.
  end

  step 'I should not see the "Leave" button for groupr "Guest"' do
    expect(find(:css, 'li', text: "Guest")).not_to have_selector(:css,  'i.fa.fa-sign-out')
    # poltergeist always confirms popups.
  end

  step 'I should see group "Owned" in group list' do
    expect(page).to have_content("Owned")
  end

  step 'I should not see group "Owned" in group list' do
    expect(page).not_to have_content("Owned")
  end

  step 'I should see group "Guest" in group list' do
    expect(page).to have_content("Guest")
  end

  step 'I should not see group "Guest" in group list' do
    expect(page).not_to have_content("Guest")
  end
end
