var fs = require("fs");
var resolve = require("path").resolve;
var join = require("path").join;
var cp = require("child_process");
var os = require("os");

console.log("Start install.js" + os.EOL);

var tasksDir = resolve(__dirname, "../out/tasks");

// Execute npm install in all subfolders of out/tasks.
function install() {
    var dirs = fs.readdirSync(tasksDir)
        .map(function (dir) {
            return join(tasksDir, dir);
        })
        .filter(function (dir) {
            return fs.existsSync(join(dir, "package.json"));
        });

    var promises = dirs
        .map(function (dir) {
            return npminstall(dir);
        });

    return Promise.all(promises);
};

function npminstall(dir) {
    return new Promise(function (resolve, reject) {
        var npmCmd = os.platform().startsWith("win") ? "npm.cmd" : "npm"

        var child = cp.spawn(
            npmCmd,
            ["i", "--production"],
            { env: process.env, cwd: dir, stdio: "inherit" }
        );

        child.on("exit", function (code) {
            if (code === 0) {
                console.log("Executed npm install in " + dir);
                resolve();
            }
            else {
                reject("Failed executing npm install in " + dir);
            }
        });
    });
}


function logCompletion() {
    console.log(os.EOL + "Installing modules finished. Files are ready in " + tasksDir);
}

install()
    .then(logCompletion)
    .catch((err) => {
        console.error(err);
    });