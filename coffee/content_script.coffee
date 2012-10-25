task_from_text_input_id = (id) ->
    match = id.match(/.*StateObjectPlaceholder-(\d+)_(\d+)/)
    if match?.length > 2
        match[2]
    else
        throw "Can't extract task id from control!"


get_tasks_from_nodes = (element_name, node_list) ->
    # Task info stored in the elements of the task-row-text-input class
    # For tasks it's <input> element and for subtask it's <textarea>
    # This method finds the task elements and conver their ids to Asana's task ids
    result = []
    for node in node_list or []
        result = result.concat(task_from_text_input_id($(input).attr("id")) for input in $(node).find("#{element_name}.task-row-text-input"))
    result

get_tasks_from_mutations = (element_name, mutation_property_name, mutations) ->
    _.flatten (get_tasks_from_nodes(element_name, mutation[mutation_property_name]) for mutation in mutations), true


display_task_catcher = (mutations) ->
    get_tasks_from_mutations "input", "addedNodes", mutations


hide_task_catcher = (mutations) ->
    get_tasks_from_mutations 'input', "removedNodes", mutations


display_subtask_catcher = (mutations) ->
    get_tasks_from_mutations 'textarea', "addedNodes", mutations


hide_subtask_catcher = (mutations) ->
    get_tasks_from_mutations 'textarea', "removedNodes", mutations

change_task_catcher = (mutations) ->
    # Task is changed when the subtask <input> element is added and removed in the same dom mutation
    display_tasks = display_task_catcher(mutations)
    hide_tasks = hide_task_catcher(mutations)
    #    i = Math.random()
    #    if display_tasks
    #        console.log "Change.Display Tasks #{i}"
    #        console.log display_tasks
    #    if  hide_tasks
    #        console.log "Change.Hide Tasks #{i}"
    #        console.log display_tasks
    _.intersection display_tasks, hide_tasks

change_subtask_catcher = (mutations) ->
    # Subtask is changed when the subtask <textarea> element is added and removed in the same dom mutation
    display_subtasks = display_subtask_catcher(mutations)
    hide_subtasks = hide_subtask_catcher(mutations)
    #    i = Math.random()
    #    if display_subtasks
    #        console.log "Change.Display Subtasks#{i}"
    #        console.log display_subtasks
    #    if  hide_subtasks
    #        console.log "Change.Hide Subtasks #{i}"
    #        console.log display_subtasks
    _.intersection display_subtasks, hide_subtasks


mutations_catcher = (mutations) ->
    [mutations]


class AsanaEventListener
    constructor: ->
        @mutation_observer = new WebKitMutationObserver(@observe_handler)
        @event_catchers =
            display_task: display_task_catcher
            hide_task: hide_task_catcher
            change_task: change_task_catcher
            display_subtask: display_subtask_catcher
            hide_subtask: hide_subtask_catcher
            change_subtask: change_subtask_catcher
            mutations: mutations_catcher

        @event_listeners = {}


    start: ->
        @mutation_observer.observe document,
            subtree: true
            attributes: true
            childList: true

    stop: ->
        @mutation_observer.disconnect()

    check_event: (event_name) ->
        throw "Unknown event: " + event_name unless event_name of @event_catchers

        @event_listeners[event_name] = [] unless event_name of @event_listeners

    on: (event_name, callback) ->
        @check_event event_name

        @event_listeners[event_name].push(callback)

    off: (event_name, callback) ->
        @check_event event_name

        @event_listeners[event_name] = (listener for listener in  @event_listeners[event_name] unless listener is callback)

    event: (event_name, data) ->
        return unless event_name of @event_listeners

        for listener in @event_listeners[event_name]
            #            try
            listener(event_name, data)
    #            catch err
    #                console.log err

    observe_handler: (mutations, observer) =>
        for event_name, catcher of @event_catchers
            @event(event_name, data) for data in (catcher(mutations) or [])


initials = (str) -> (word.substr(0, 1) for word in str.split(' ')).join('')


get_current_project = ->
    match = document.URL.match(/.*app.asana.com\/0\/(\d+)\/\d+/) # TODO: finish this
    if match?.length > 1
        match[1]
    else
        throw "Can't extract project id from URL!"


class Task extends Backbone.Model
    defaults:
        data:{}
        subtasks:{}

    get_trello_url: ->
        match = @get('data').notes.match(/(https:\/\/trello.com\/c\/\S+)/)
        match[1] if match?.length > 1


class TaskView extends Backbone.View
    initialize: ->
        _.bindAll @
        @model.bind "change", @render

    find_task_div: ->
        selector = "#center_pane input[id$=#{@model.get("data").id}]"
        $(selector).first()

    render: ->
        console.log "Rendering task #{@model.get("data").name}"
        div = @find_task_div()
        return unless div

        parent = div.parent()
        task_row_overlay = parent.find('.task-row-overlay')

        # clear all our old stuff
        task_row_overlay.find(".subtask").remove()
        task_row_overlay.find(".trello-icon").remove()


        # render Trello part
        if url = @model.get_trello_url()
            task_row_overlay.prepend """<div class='trello-icon'><a href='#{url}' target='_blank'>
                <img src='https://trello.com/favicon.ico'></div></a>"""

        # render Subtask part
        subtask_ids = (st.id for st in @model.get "subtasks")
        if subtask_ids?.length
            subtasks = (tasks[id].get('data') for id in subtask_ids when id of tasks)

            uncompleted_unassigned_subtasks_num = (st for st in subtasks when not st.completed and not st.assignee).length

            if uncompleted_unassigned_subtasks_num
                task_row_overlay.prepend """<span class='subtask subtask-counter unassigned' title='Uncompleted unassigned subtasks'>
                                                                                #{uncompleted_unassigned_subtasks_num}</span>"""

            active_assignees =
                _.without(
                    _.uniq(
                        _.map(
                            subtasks
                            (st) ->
                                if st.assignee and not st.completed
                                    st.assignee.name
                                else
                                    null
                        )
                    )
                    null)


            for assignee in active_assignees
                task_row_overlay.prepend "<span class='subtask user' title='#{assignee}'>#{initials(assignee)}</span>"

            task_row_overlay.prepend "<i class='subtask icon-subtasks'></i>"

            task_row_overlay.find(".subtask").tooltip({delay:
                { show: 200, hide: 100 }})

            @

class SubTaskView extends Backbone.View
    initialize: ->
        _.bindAll @
        @model.bind "change", @render

    find_task_div: ->
        selector = "#right_pane textarea[id$=#{@model.get("data").id}]"
        $(selector).first()

    render: ->
        console.log "Rendering subtask #{@model.get("data").name}"
        div = @find_task_div()
        return unless div

        parent = div.parent()
        task_row_overlay = parent.find('.task-row-overlay')

        # TODO:clear all our old stuff


        # render Trello part
        if url = @model.get_trello_url()
            task_row_overlay.prepend """<div class='trello-icon'><a href='#{url}' target='_blank'>
                            <img src='http://trello.com/favicon.ico'></div></a>"""


asana_event_listener = new AsanaEventListener()

# Loggers

logger_with_event = (event, data) ->
    console.log "Event fired: #{event}"
    console.log data

log_node_list = (nodelist) ->
    console.log(node.outerHTML) for node in (nodelist or [])

mutation_logger = (event, mutation) ->
    console.log mutation
    if mutation.addedNodes
        console.log("Added nodes")
        log_node_list(mutation.addedNodes)
    if mutation.removedNodes
        console.log("Removed nodes")
        log_node_list(mutation.removedNodes)

# Task-related handlers

tasks = {}

render_task = (task) ->
    view = new TaskView({model: task})
    view.render()

ensure_subtasks = (task, callback) ->
    subtasks = task.get "subtasks"
    callback() unless subtasks?.length

    requests = subtasks.length
    for subtask_rec in subtasks
        ensure_task subtask_rec.id, (subtask) ->
            callback() unless --requests


get_task_from_server = (task_id, callback) ->
    Asana.task task_id, (task_obj, error) ->
        if error
            console.log error
            return
        task = new Task({data: task_obj.data})
        Asana.subtasks task_id, (subtasks_obj, error) ->
            if error
                console.log error
                return
            task.set "subtasks", subtasks_obj.data
            ensure_subtasks task, ->
                tasks[task_id] = task
                callback task

ensure_task = (task_id, callback) ->
    if task_id of tasks
        task = tasks[task_id]
        callback(task)
    else
        get_task_from_server task_id, callback

display_task_event_handler = (event, task_id) ->
    console.log "Display task event handler task_id=#{task_id}"
    ensure_task(task_id, render_task)


render_subtask = (task) ->
    view = new SubTaskView({model: task})
    view.render()


display_subtask_event_handler = (event, task_id) ->
    ensure_task(task_id, render_subtask)


iterate_all_nodes = (record, callback) ->
    if record?.addedNodes
        for node in record.addedNodes
            callback(node)
    if record?.removedNodes
        for node in record.removedNodes
            callback(node)


asana_event_listener.on "display_task", display_task_event_handler

# Image-related handlers

show_task_pictures = (root) ->
    jQuery(root).find(".comments .attachment-link-to-file").each ->
        $this = $(this)
        URL = $this.attr("href")
        file_name = $this.text()

        # console.log("Found image:" + file_name);
        if not $this.data("image_expanded") and /(\.png|\.jpg|\.gif)$/.test(file_name)
            $this.data "image_expanded", "true"
            $this.html "<img style=\"max-width:100%;\" src=\"" + URL + "\">"
            outerHtml = $this.clone().wrap("<p>").parent().html()
            time_el = $this.parent().parent().parent().parent().find("div.feed-story-timestamp span")
            time = time_el.text()
            time_el.remove()
            $this.parent().html "attached. " + time + outerHtml


show_picture_mutation_handler = (event, mutations)->
    for mutation_record in mutations
        if mutation_record.addedNodes and $(mutation_record.target).parents('#right_pane').length
            for added_node in mutation_record.addedNodes
                show_task_pictures(added_node)



asana_event_listener.on "mutations", show_picture_mutation_handler



# Start the listener

asana_event_listener.start()



#asana_event_listener.on "display_task", logger_with_event
#asana_event_listener.on "hide_task", logger_with_event
#asana_event_listener.on "change_task", logger_with_event
#asana_event_listener.on "display_subtask", logger_with_event
#asana_event_listener.on "hide_subtask", logger_with_event
#asana_event_listener.on "change_subtask", logger_with_event

#
#$('body').append """
#<script>
#(function () {
#    var get_xhr;
#    if (!window.MochiKit) console.log("No MochiKit found!");
#    get_xhr = window.MochiKit.Async.getXMLHttpRequest;
#    window.MochiKit.Async.getXMLHttpRequest = function () {
#        var xhr;
#        xhr = get_xhr();
#        console.log("New XHR!!!", xhr);
#        xhr.addEventListener("load", function (evt) {
#            console.log("Request completed");
#            console.log(evt);
#            console.log(evt.target._url);
#
#        });
#        return xhr;
#    }
#})();
#</script>
#"""

#setTimeout (() ->
#    get_xhr = window.MochiKit.Async.getXMLHttpRequest
#
#    window.MochiKit.Async.getXMLHttpRequest = () ->
#        xhr = get_xhr()
#        console.log "New XHR!!!"
#        xhr.addEventListener "load", (evt) ->
#            console.log("Request completed")
#            console.log(evt)
#        xhr
#    ), 3000
























