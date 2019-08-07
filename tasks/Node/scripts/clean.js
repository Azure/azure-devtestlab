var fs = require('fs');
var path = require('path');
var rimraf = require('rimraf');

var distDir = path.resolve(__dirname, '../dist');
var outDir = path.resolve(__dirname, '../out');
var azureDir = path.resolve(__dirname, '../node_modules/@azure');

function clean(destDir) {
  rimraf(destDir, function (err) {
    if (err) {
      console.error('Error cleaning directory: ' + destDir);
      process.exit(1);
    }

    console.log('Cleaned ' + destDir);
  });
}

function cleanModules(modulesDir) {
  if (!fs.existsSync(modulesDir)) {
    return;
  }
  var items = fs.readdirSync(modulesDir);
  for (var i = 0; i < items.length; i++) {
    var item = path.resolve(modulesDir, items[i]);
    if (fs.statSync(item).isDirectory()) {
      if (items[i] === 'node_modules') {
        clean(item);
      }
      else {
        cleanModules(item);
      }
    }
  }
}

var args = require('minimist')(process.argv.slice(2));
if (args.submods) {
  console.log('Cleaning modules only under directory: ' + azureDir)
  cleanModules(azureDir);
}
else {
  var destDir = args.dev ? outDir : distDir;
  console.log('Cleaning under directory: ' + destDir)
  clean(destDir);
}