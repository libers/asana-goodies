$.fn.hasAncestor = function (a) {
    return this.filter(function () {
        return !!$(this).closest(a).length;
    });
};


var show_task_pictures = function (root) {
    jQuery(root).find('.comments .attachment-link-to-file').each(function () {
        var $this = jQuery(this);
        var URL = $this.attr('href');
        var file_name = $this.text();

        // console.log("Found image:" + file_name);
        if (!$this.data("image_expanded") && /(\.png|\.jpg|\.gif)$/.test(file_name)) {
            $this.data("image_expanded", 'true');
            $this.html('<img style="max-width:100%;" src="' + URL + '">');

            var outerHtml = $this.clone().wrap('<p>').parent().html();
            var time_el = $this.parent().parent().parent().parent().find("div.feed-story-timestamp span");
            var time = time_el.text();
            time_el.remove();
            $this.parent().html("attached. " + time + outerHtml);
        }
    });
};


var proj_task = function (id) {
    var match_list = id.match(/.*StateObjectPlaceholder-(\d+)_(\d+)/);
    return match_list.slice(1);
};


var UPDATE_INTERVAL = 20;



var Updater = function (update_key) {
    this.update_key = update_key;
};

Updater.prototype.can_update = function ($dom_element) {
    var last_update = $dom_element.data(this.update_key);
    if (!last_update) {
        console.log("Empty node - can update");
        return true;
    }
    var seconds_since_last_update = (new Date() - last_update ) / 1000;
    console.log("Seconds since last update: " + seconds_since_last_update);
    return seconds_since_last_update > UPDATE_INTERVAL;
};

Updater.prototype.before_update = function ($dom_element) {
    $dom_element.data(this.update_key, new Date());
};

var trello_updater = new Updater("trello-updated");

trello_updater.update_task = function (task, text_input) {
    if (!this.can_update(text_input)) return;

    text_input.parent().find(".trello_icon").remove();

    text_input.data(this.update_key, new Date());
    if (task.data.notes.indexOf("https://trello.com/c") != -1) {
        text_input.parent().append(
            "<div class='trello_icon' style='float:right;'><img src='http://trello.com/favicon.ico' style='width:14px;height:14px;'></div>")
    }
};


var initials = function (str) {
    return _.map(str.split(' '),function (word) {
        return word.substr(0, 1);
    }).join("");
};

var add_subtasks_icons = function (subtasks, text_input) {
    if (!subtasks.length) return;

    var uncompleted_unassigned_subtasks_num = _.filter(subtasks,function (st) {
        return st.completed && st.assignee;
    }).length;

    var active_assignees = _.without(_.uniq(_.map(subtasks, function (st) {
        if (!st.assignee || st.completed) return null;

        return st.assignee.name;
    })), null);

    var div = text_input.parent().find('.task-row-overlay');

    if (uncompleted_unassigned_subtasks_num) {
        div.prepend("<span class='subtask subtask-counter unassigned' title='Uncompleted unassigned subtasks'>"
            + uncompleted_unassigned_subtasks_num + "</span>");
    }
    active_assignees.forEach(function (assignee) {
        div.prepend("<span class='subtask user' title='" + assignee + "'>" + initials(assignee) + "</span>");
    });

    div.prepend("<i class='subtask icon-subtasks'></i>");

    var tooltip_options = {delay:{ show:200, hide:100 }};

    div.find(".subtask").tooltip(tooltip_options);
};

var subtask_updater = new Updater("subtask-updated");

subtask_updater.update_task = function (task, text_input) {
    if (!this.can_update(text_input)) return;
    this.before_update(text_input);

    text_input.parent().find(".subtask").remove();

    Asana.subtasks(task.data.id, function (data_obj) {
        var requests = data_obj.data.length;
        var subtasks = [];

        data_obj.data.forEach(function (subtask) {
            Asana.task(subtask.id, function (subtask_data_obj) {
                subtasks.push(subtask_data_obj.data);
                if (--requests === 0) {
                    add_subtasks_icons(subtasks, text_input);
                }
            });
        });
    });
};


var task_updaters = [trello_updater, subtask_updater];

var update_queue = {};

var update_tasks = function (selector) {
    if (update_queue[selector]) {
        console.log("Already updating for selector " + selector);
        return;
    }

    var nodes = jQuery(selector);
    console.log("Found " + nodes.length + " nodes for selector " + selector);

    update_queue[selector] = selector;
    nodes.each(function (index, element) {
        //console.log("Value of task name:" + $(element).val());

        //console.log(this);
        var $this = jQuery(this);
        var res = proj_task(jQuery(this).attr('id'));
        var proj = res[0];
        var task = res[1];

//        console.log("Project#:" + proj + ", Task#:" + task);

        var this_is_selected = $this.parent().parent().parent().hasClass('');


        var filtered_updaters = task_updaters;

        filtered_updaters = _.filter(task_updaters, function (updater) {
            return updater.can_update($this);
        });

//        console.log("Updaters");
//        console.log(filtered_updaters);

        if (filtered_updaters && filtered_updaters.length) {
            Asana.task(task, function (task_obj) {
//                console.log("Task data received");
//                console.log(JSON.stringify(task_obj, null, 4));

                filtered_updaters.forEach(function (updater) {
                    updater.update_task(task_obj, $this);
                });
            });
        }
    });
    delete update_queue[selector];
};

var update_current_task = function () {
    update_tasks(".grid-row-selected input.task-row-text-input");
};

var update_all_tasks = function () {
    update_tasks("#center_pane input.task-row-text-input");
    setTimeout(update_all_tasks, 5000);
};

$(function () {
    //update_all_tasks();
});


//var observer = new WebKitMutationObserver(function (mutations, observer) {
////    console.log("Mutated!");
//
//    var right_only = true;
//
//    mutations.forEach(function (mutation) {
//        if ($(mutation.target).parent('#right_pane').length) {
//            right_only = false;
//        }
//    });
//
//    if (right_only) {
//        show_task_pictures(document);
//        update_current_task();
//    } else {
//        update_all_tasks();
//    }
//
//});

var log_mutation = function(mutation) {
    if (mutation.addedNodes) {
        for(var i =0; i<mutation.addedNodes.length; ++i) {
            var node = mutation.addedNodes[i];
            $(node).find("input.task-row-text-input").each(function(index, input) {
                console.log("Added task: " + input.outerHTML);
                console.log(mutation);
            });
            $(node).find("textarea.task-row-text-input").each(function(index, input) {
                console.log("Added sub task: " + input.outerHTML);
            });
        }
    }
    if (mutation.removedNodes) {
        for(var i =0; i<mutation.removedNodes.length; ++i) {
            var node = mutation.removedNodes[i];
            $(node).find("input.task-row-text-input").each(function(index, input) {
                console.log("Deleted task: " + input.outerHTML);
            });
            $(node).find("textarea.task-row-text-input").each(function(index, input) {
                console.log("Deleted sub task: " + input.outerHTML);
            });
        }
    }
};


var observer = new WebKitMutationObserver(function (mutations, observer) {
//    console.log("Mutated!");

    var right_only = true;

    mutations.forEach(function (mutation) {
        if ($(mutation.target).parent('#right_pane').length) {
            console.log("Right Pane");
        }
        if ($(mutation.target).parent('#center_pane').length) {
            console.log("Center Pane");
        }
        if ($(mutation.target).parent('#left_pane').length) {
            console.log("Left Pane");
        }

        log_mutation(mutation);
    });

});

observer.observe(document, {
    subtree:true,
    attributes:true,
    childList:true
});

