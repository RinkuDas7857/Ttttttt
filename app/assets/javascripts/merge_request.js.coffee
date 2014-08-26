class MergeRequest
  constructor: (@opts) ->
    @initContextWidget()
    this.$el = $('.merge-request')
    @tabs_loaded =
      diffs: false
      conflicts: false
    @tabs_loaded[@opts.action] = true
    @commits_loaded = false

    this.activateTab(@opts.action)

    this.bindEvents()

    this.initMergeWidget()
    this.$('.show-all-commits').on 'click', =>
      this.showAllCommits()

    modal = $('#modal_merge_info').modal(show: false)

    disableButtonIfEmptyField '#merge_commit_message', '.accept_merge_request'


  # Local jQuery finder
  $: (selector) ->
    this.$el.find(selector)

  initContextWidget: ->
    $('.edit-merge_request.inline-update input[type="submit"]').hide()
    $(".issue-box .inline-update").on "change", "select", ->
      $(this).submit()
    $(".issue-box .inline-update").on "change", "#merge_request_assignee_id", ->
      $(this).submit()

  initMergeWidget: ->
    this.showState( @opts.current_status )

    if this.$('.automerge_widget').length and @opts.check_enable
      $.get @opts.url_to_automerge_check, (data) =>
        this.showState( data.merge_status )
      , 'json'

    if @opts.ci_enable
      $.get @opts.url_to_ci_check, (data) =>
        this.showCiState data.status
      , 'json'

  bindEvents: ->
    this.$('.merge-request-tabs').on 'click', 'a', (event) =>
      a = $(event.currentTarget)

      href = a.attr('href')
      History.replaceState {path: href}, document.title, href

      event.preventDefault()

    this.$('.merge-request-tabs').on 'click', 'li', (event) =>
      this.activateTab($(event.currentTarget).data('action'))

    this.$('.accept_merge_request').on 'click', ->
      $('.automerge_widget.can_be_merged').hide()
      $('.merge-in-progress').show()

    this.$('.remove_source_branch').on 'click', ->
      $('.remove_source_branch_widget').hide()
      $('.remove_source_branch_in_progress').show()

    this.$(".remove_source_branch").on "ajax:success", (e, data, status, xhr) ->
      location.reload()

    this.$(".remove_source_branch").on "ajax:error", (e, data, status, xhr) =>
      this.$('.remove_source_branch_widget').hide()
      this.$('.remove_source_branch_in_progress').hide()
      this.$('.remove_source_branch_widget.failed').show()

  bindTabEvents: (action) ->
    tab = this.tabFromAction(action)
    switch action
      when "conflicts"
        tab.find(".actions .button-holder").on "click", ->
          textarea = $(this).closest('tbody').find('textarea')
          textarea.val(textarea.val() + '\n' + $(this).next().text())

  activateTab: (action) ->
    this.$('.merge-request-tabs li').removeClass 'active'
    this.$('.tab-content').hide()
    if action == 'diffs' or action == 'conflicts'
      this.$(".merge-request-tabs .#{action}-tab").addClass 'active'
      this.loadTab(action) unless @tabs_loaded[action]
      this.bindTabEvents(action)
      this.tabFromAction(action).show()
    else
      this.$('.merge-request-tabs .notes-tab').addClass 'active'
      this.$('.notes').show()

  showState: (state) ->
    $('.automerge_widget').hide()
    $('.automerge_widget.' + state).show()

  showCiState: (state) ->
    $('.ci_widget').hide()
    allowed_states = ["failed", "running", "pending", "success"]
    if state in allowed_states
      $('.ci_widget.ci-' + state).show()
    else
      $('.ci_widget.ci-error').show()

    switch state
      when "success"
        $('.mr-state-widget').addClass("panel-success")
      when "failed"
        $('.mr-state-widget').addClass("panel-danger")
      when "running", "pending"
        $('.mr-state-widget').addClass("panel-warning")

  loadTab: (action) ->
    $.ajax
      type: 'GET'
      url: this.$(".merge-request-tabs .#{action}-tab a").attr("href")
      beforeSend: =>
        this.$(".mr-loading-status .loading").show()
      complete: =>
        @tabs_loaded[action] = true
        this.$(".mr-loading-status .loading").hide()
      success: (data) =>
        tab_content = this.tabFromAction(action)
        tab_content.html(data.html)
        this.bindTabEvents(action)
      dataType: "json"

  showAllCommits: ->
    this.$('.first-commits').remove()
    this.$('.all-commits').removeClass 'hide'

  alreadyOrCannotBeMerged: ->
    this.$('.automerge_widget').hide()
    this.$('.merge-in-progress').hide()
    this.$('.automerge_widget.already_cannot_be_merged').show()

  tabFromAction: (action) ->
    this.$(".#{action}")

this.MergeRequest = MergeRequest
