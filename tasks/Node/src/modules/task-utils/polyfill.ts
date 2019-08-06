import 'isomorphic-fetch';

if (!console.debug) {
    var isDebugMode = process.env.NODE_ENV != 'production';

    console.debug = function (args) {
        if (isDebugMode) {
            console.log(args);
        }
    }
}