import 'isomorphic-fetch';

if (!console.debug) {
    const isDebugMode = process.env.NODE_ENV != 'production';

    console.debug = function (args) {
        if (isDebugMode) {
            console.log(args);
        }
    }
}