/**
 * Created with JetBrains WebStorm.
 * User: mturilin
 * Date: 10/21/12
 * Time: 9:45 PM
 * To change this template use File | Settings | File Templates.
 */

(function () {
    var get_xhr;
    if (!window.MochiKit) console.log("No MochiKit found!");
    get_xhr = window.MochiKit.Async.getXMLHttpRequest;
    window.MochiKit.Async.getXMLHttpRequest = function () {
        var xhr = get_xhr();
        console.log("New XHR!!!", xhr);

        var open = xhr.prototype.open;

        xhr.prototype.open = function (method, url, async, user, pass) {
            console.log("Opening url: ", url);
            open.call(this, method, url, async, user, pass);
        };

        return xhr;
    }
})();