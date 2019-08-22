var ncp = require('ncp').ncp;
var path = require('path');
var os = require('os');

console.log('Start copy.js' + os.EOL);

var srcDir = path.resolve(__dirname, '../src');
var distDir = path.resolve(__dirname, '../dist');
var outDir = path.resolve(__dirname, '../out');

function copySrc(srcDir, destDir) {
    return new Promise(function (resolve, reject) {
        ncp(srcDir, destDir, {
            filter: function (name) {
                var includeFile = name.indexOf('.ts') === -1
                    && name.indexOf('testdata.json') === -1
                    && name.indexOf('modules') === -1
                    && name.indexOf('tests') === -1;
                return includeFile;
            }
        }, function (err) {
            if (err) {
                reject(err);
                return;
            }
            console.log('Copied files from ' + srcDir + ' to ' + destDir);
            resolve();
        });
    });
}

function logCompletion(destDir) {
    console.log(os.EOL + 'Copy finished. Files are ready in ' + destDir);
}

var args = require('minimist')(process.argv.slice(2));
var destDir = args.dev ? outDir : distDir;
copySrc(srcDir, destDir)
    .then(logCompletion(destDir))
    .catch((err) => {
        console.error(err);
    });