/**
 * Created with JetBrains WebStorm.
 * User: mturilin
 * Date: 10/16/12
 * Time: 10:03 PM
 * To change this template use File | Settings | File Templates.
 */

var ASANA_BASE_URL = "https://app.asana.com/api/1.0/";

var Asana = {
    task: function(id, callback) {
        this.asana_call("tasks/" + id, callback)
    },

    subtasks: function(id, callback) {
        this.asana_call("tasks/" + id + "/subtasks", callback);
    },

    asana_call: function(endpoint, callback) {
        $.ajax(ASANA_BASE_URL + endpoint, {
            success: function(data, text_status, jqXHR) {
                callback(data, null);
            },
            error: function(jqXHR, textStatus, errorThrown) {
                callback(null, errorThrown);
            }
        })
    }
};