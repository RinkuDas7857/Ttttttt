# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::CreateService, '#execute', feature_category: :groups_and_projects do
  let_it_be(:user, reload: true) { create(:user) }
  let(:current_user) { user }
  let(:group_params) { { path: 'group_path', visibility_level: Gitlab::VisibilityLevel::PUBLIC }.merge(extra_params) }
  let(:extra_params) { {} }
  let(:created_group) { response }

  subject(:response) { described_class.new(current_user, group_params).execute }

  shared_examples 'has sync-ed traversal_ids' do
    specify do
      expect(created_group.traversal_ids).to eq([created_group.parent&.traversal_ids, created_group.id].flatten.compact)
    end
  end

  shared_examples 'creating a group' do
    specify do
      expect { response }.to change { Group.count }
      expect(created_group).to be_persisted
    end
  end

  shared_examples 'does not create a group' do
    specify do
      expect { response }.not_to change { Group.count }
      expect(created_group).not_to be_persisted
    end
  end

  context 'for visibility level restrictions' do
    context 'without restricted visibility level' do
      it_behaves_like 'creating a group'
    end

    context 'with restricted visibility level' do
      before do
        stub_application_setting(restricted_visibility_levels: [Gitlab::VisibilityLevel::PUBLIC])
      end

      it_behaves_like 'does not create a group'
    end
  end

  context 'with `setup_for_company` attribute' do
    let(:extra_params) { { setup_for_company: true } }

    it 'has the specified setup_for_company' do
      expect(created_group.setup_for_company).to eq(true)
    end
  end

  context 'with `default_branch_protection` attribute' do
    let(:extra_params) { { default_branch_protection: Gitlab::Access::PROTECTION_NONE } }

    context 'for users who have the ability to create a group with `default_branch_protection`' do
      it 'creates group with the specified branch protection level' do
        expect(created_group.default_branch_protection).to eq(Gitlab::Access::PROTECTION_NONE)
      end
    end

    context 'for users who do not have the ability to create a group with `default_branch_protection`' do
      it 'does not create the group with the specified branch protection level' do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :create_group_with_default_branch_protection).and_return(false)

        expect(created_group.default_branch_protection).not_to eq(Gitlab::Access::PROTECTION_NONE)
      end
    end
  end

  context 'with `default_branch_protection_defaults` attribute' do
    let(:branch_protection) { ::Gitlab::Access::BranchProtection.protected_against_developer_pushes.stringify_keys }
    let(:extra_params) { { default_branch_protection_defaults: branch_protection } }

    context 'for users who have the ability to create a group with `default_branch_protection`' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability)
          .to receive(:allowed?).with(user, :update_default_branch_protection, an_instance_of(Group)).and_return(true)
      end

      it 'creates group with the specified default branch protection settings' do
        expect(created_group.default_branch_protection_defaults).to eq(branch_protection)
      end
    end

    context 'for users who do not have the ability to create a group with `default_branch_protection_defaults`' do
      it 'does not create the group with the specified default branch protection settings' do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :create_group_with_default_branch_protection).and_return(false)

        expect(created_group.default_branch_protection_defaults).not_to eq(Gitlab::Access::PROTECTION_NONE)
      end
    end
  end

  context 'with `allow_mfa_for_subgroups` attribute' do
    let(:extra_params) { { allow_mfa_for_subgroups: false } }

    it_behaves_like 'creating a group'
  end

  context 'with `math_rendering_limits_enabled` attribute' do
    let(:extra_params) { { math_rendering_limits_enabled: false } }

    it_behaves_like 'creating a group'
  end

  context 'with `lock_math_rendering_limits_enabled` attribute' do
    let(:extra_params) { { lock_math_rendering_limits_enabled: false } }

    it_behaves_like 'creating a group'
  end

  context 'for a top level group' do
    context 'when user can create a group' do
      before do
        user.update_attribute(:can_create_group, true)
      end

      it_behaves_like 'creating a group'

      context 'with before_commit callback' do
        it_behaves_like 'has sync-ed traversal_ids'
      end
    end

    context 'when user can not create a group' do
      before do
        user.update_attribute(:can_create_group, false)
      end

      it_behaves_like 'does not create a group'
    end
  end

  context 'when creating a group within an organization' do
    let_it_be(:other_organization) { create(:organization, name: 'Other Organization') }

    context 'when organization is provided' do
      let_it_be(:organization) { create(:organization) }
      let(:extra_params) { { organization_id: organization.id } }

      context 'when user can create the group' do
        before do
          create(:organization_user, user: user, organization: organization)
        end

        it_behaves_like 'creating a group'
      end

      context 'when user is an admin', :enable_admin_mode do
        let(:current_user) { create(:admin) }

        it_behaves_like 'creating a group'
      end

      context 'when user can not create the group' do
        it_behaves_like 'does not create a group'

        it 'returns an error and does not set organization_id' do
          expect(created_group.errors[:organization_id].first)
            .to eq(s_("CreateGroup|You don't have permission to create a group in the provided organization."))
          expect(created_group.organization_id).to be_nil
        end
      end

      context 'when parent group is different from provided group' do
        let_it_be(:parent_group) { create(:group, organization: other_organization) }
        let(:extra_params) { { parent_id: parent_group.id, organization_id: organization.id } }

        before_all do
          create(:organization_user, user: user, organization: organization)
          create(:organization_user, user: user, organization: other_organization)
          parent_group.add_owner(user)
        end

        it_behaves_like 'does not create a group'

        it 'returns an error and does not set organization_id' do
          expect(created_group.errors[:organization_id].first)
            .to eq(s_("CreateGroup|You can't create a group in a different organization than the parent group."))
          expect(created_group.organization_id).to be_nil
        end
      end
    end

    context 'when organization is not set by params' do
      let_it_be(:default_organization) { create(:organization, :default) }
      let_it_be(:current_organization) { create(:organization, name: 'Current Organization') }

      context 'and the parent of the group has an organization' do
        let_it_be(:parent_group) { create(:group, organization: other_organization) }

        let(:extra_params) { { parent_id: parent_group.id } }

        it 'creates group with the parent group organization' do
          expect(created_group.organization).to eq(other_organization)
        end
      end

      context 'and current_organization is known' do
        before do
          allow_next_instance_of(Groups::CreateService) do |instance|
            allow(instance).to receive(:current_organization).and_return(current_organization)
          end
        end

        it 'creates group with the current organization' do
          expect(created_group.organization).to eq(current_organization)
        end
      end

      context 'and no group can be found' do
        it 'creates group with the default organization' do
          expect(created_group.organization).to eq(default_organization)
        end
      end
    end
  end

  context 'for a subgroup' do
    let_it_be(:group) { create(:group) }
    let(:extra_params) { { parent_id: group.id } }

    context 'as group owner' do
      before_all do
        group.add_owner(user)
      end

      it_behaves_like 'creating a group'
      it_behaves_like 'has sync-ed traversal_ids'
    end

    context 'as guest' do
      it_behaves_like 'does not create a group'

      it 'returns an error and does not set parent_id' do
        expect(created_group.errors[:parent_id].first)
          .to eq(s_('CreateGroup|You don’t have permission to create a subgroup in this group.'))
        expect(created_group.parent_id).to be_nil
      end
    end

    context 'as owner' do
      before_all do
        group.add_owner(user)
      end

      it_behaves_like 'creating a group'
    end

    context 'as maintainer' do
      before_all do
        group.add_maintainer(user)
      end

      it_behaves_like 'creating a group'
    end
  end

  context 'when visibility level is passed as a string' do
    let(:extra_params) { { visibility: 'public' } }

    it 'assigns the correct visibility level' do
      expect(created_group.visibility_level).to eq(Gitlab::VisibilityLevel::PUBLIC)
    end
  end

  context 'for creating a mattermost team' do
    let(:extra_params) { { create_chat_team: 'true' } }

    before do
      stub_mattermost_setting(enabled: true)
    end

    it 'create the chat team with the group' do
      allow_next_instance_of(::Mattermost::Team) do |instance|
        allow(instance).to receive(:create).and_return({ 'name' => 'tanuki', 'id' => 'lskdjfwlekfjsdifjj' })
      end

      expect { response }.to change { ChatTeam.count }.from(0).to(1)
    end
  end

  context 'for creating a setting record' do
    it 'create the settings record connected to the group' do
      expect(created_group.namespace_settings).to be_persisted
    end
  end

  context 'for creating a details record' do
    it 'create the details record connected to the group' do
      expect(created_group.namespace_details).to be_persisted
    end
  end

  context 'with an active instance-level integration' do
    let_it_be(:instance_integration) do
      create(:prometheus_integration, :instance, api_url: 'https://prometheus.instance.com/')
    end

    it 'creates a service from the instance-level integration' do
      expect(created_group.integrations.count).to eq(1)
      expect(created_group.integrations.first.api_url).to eq(instance_integration.api_url)
      expect(created_group.integrations.first.inherit_from_id).to eq(instance_integration.id)
    end

    context 'with an active group-level integration' do
      let(:extra_params) { { parent_id: group.id } }
      let_it_be(:group) { create(:group) { |g| g.add_owner(user) } }
      let_it_be(:group_integration) do
        create(:prometheus_integration, :group, group: group, api_url: 'https://prometheus.group.com/')
      end

      it 'creates a service from the group-level integration' do
        expect(created_group.integrations.count).to eq(1)
        expect(created_group.integrations.first.api_url).to eq(group_integration.api_url)
        expect(created_group.integrations.first.inherit_from_id).to eq(group_integration.id)
      end

      context 'with an active subgroup' do
        let(:extra_params) { { parent_id: subgroup.id } }
        let_it_be(:subgroup) { create(:group, parent: group) { |g| g.add_owner(user) } }
        let_it_be(:subgroup_integration) do
          create(:prometheus_integration, :group, group: subgroup, api_url: 'https://prometheus.subgroup.com/')
        end

        it 'creates a service from the subgroup-level integration' do
          expect(created_group.integrations.count).to eq(1)
          expect(created_group.integrations.first.api_url).to eq(subgroup_integration.api_url)
          expect(created_group.integrations.first.inherit_from_id).to eq(subgroup_integration.id)
        end
      end
    end
  end

  context 'with shared runners configuration' do
    context 'when parent group is present' do
      using RSpec::Parameterized::TableSyntax

      where(:shared_runners_config, :descendants_override_disabled_shared_runners_config) do
        true  | false
        false | false
        # true  | true # invalid at the group level, leaving as comment to make explicit
        false | true
      end

      with_them do
        let(:extra_params) { { parent_id: group.id } }
        let(:group) do
          create(
            :group,
            shared_runners_enabled: shared_runners_config,
            allow_descendants_override_disabled_shared_runners: descendants_override_disabled_shared_runners_config
          )
        end

        before do
          group.add_owner(user)
        end

        it 'creates group following the parent config' do
          expect(created_group.shared_runners_enabled).to eq(shared_runners_config)
          expect(created_group.allow_descendants_override_disabled_shared_runners)
            .to eq(descendants_override_disabled_shared_runners_config)
        end
      end
    end

    context 'for root group' do
      it 'follows default config' do
        expect(created_group.shared_runners_enabled).to eq(true)
        expect(created_group.allow_descendants_override_disabled_shared_runners).to eq(false)
      end
    end
  end
end
