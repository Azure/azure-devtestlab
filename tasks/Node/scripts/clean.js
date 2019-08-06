var rimraf = require("rimraf");
var path = require("path");

var distDir = path.resolve(__dirname, "../dist");
var outDir = path.resolve(__dirname, "../out");

function clean(destDir) {
  rimraf(destDir, function(err) {
    if (err) {
      console.error("Error cleaning directory: " + destDir);
      process.exit(1);
    }
  
    console.log("Cleaned " + destDir);
  });
}

var args = require('minimist')(process.argv.slice(2));
var destDir = args.dev ? outDir : distDir;
clean(destDir);