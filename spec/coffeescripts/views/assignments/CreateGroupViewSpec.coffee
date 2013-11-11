define [
  'underscore'
  'Backbone'
  'compiled/collections/AssignmentGroupCollection'
  'compiled/models/AssignmentGroup'
  'compiled/models/Assignment'
  'compiled/views/assignments/CreateGroupView'
  'jquery'
  'helpers/jquery.simulate'
  'helpers/fakeENV'
], (_, Backbone, AssignmentGroupCollection, AssignmentGroup, Assignment, CreateGroupView, $) ->

  group = ->
    new AssignmentGroup
      assignments: [new Assignment, new Assignment]

  assignmentGroups = ->
    @groups = new AssignmentGroupCollection([group(), group()])

  createView = (hasAssignmentGroup=true)->
    args =
      assignmentGroups: assignmentGroups()
      assignmentGroup: @groups.first() if hasAssignmentGroup

    view = new CreateGroupView(args)

  module 'CreateGroupView'

  test 'it should not add errors when never_drop rules are added', ->
    view = createView()
    data =
      name: "Assignments"
      rules:
        never_drop: ["1854", "352", "234563"]

    errors = view.validateFormData(data)
    ok _.isEmpty(errors)


  test 'it should only allow positive numbers for drop rules', ->
    view = createView()
    data =
      rules:
        drop_lowest: "tree"
        drop_highest: -1
        never_drop: ['1', '2', '3']

    errors = view.validateFormData(data)
    ok errors
    equal _.keys(errors).length, 2


  test 'it should only allow less than the number of assignments for drop rules', ->
    view = createView()
    assignments = view.assignmentGroup.get('assignments')

    data =
      rules:
        drop_highest: 5

    errors = view.validateFormData(data)
    ok errors
    equal _.keys(errors).length, 1


  test 'it should trigger a render event on save success when editing', ->
    triggerSpy = sinon.spy(AssignmentGroupCollection::, 'trigger')
    view = createView()
    view.onSaveSuccess()
    ok triggerSpy.calledWith 'render'
    triggerSpy.restore()

  test 'it should call render on save success if adding an assignmentGroup', ->
    view = createView(false)
    renderStub = sinon.stub(view, 'render')
    calls = renderStub.callCount
    view.onSaveSuccess()
    equal renderStub.callCount, calls + 1