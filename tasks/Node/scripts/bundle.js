const webpack = require('webpack');
const formatWebpackMessages = require('react-dev-utils/formatWebpackMessages');

const config = require('../webpack.config');

// remove this for non PROD builds
process.env.NODE_ENV = 'production';

// Create the production build and print the deployment instructions.
function bundle() {
  console.log('Creating an optimized production build...');

  let compiler = webpack(config);
  return new Promise((resolve, reject) => {
    compiler.run((err, stats) => {
      let messages;
      if (err) {
        if (!err.message) {
          return reject(err);
        }
        messages = formatWebpackMessages({
          errors: [err.message],
          warnings: []
        });
      } else {
        const rawMessages = stats.toJson({ all: false, warnings: true, errors: true })
        messages = formatWebpackMessages({
          errors: rawMessages.errors.map((e) => e.message),
          warnings: rawMessages.warnings.map((e) => e.message),
        });
      }
      if (messages.errors.length) {
        // Only keep the first error. Others are often indicative
        // of the same problem, but confuse the reader with noise.
        if (messages.errors.length > 1) {
          messages.errors.length = 1;
        }
        return reject(new Error(messages.errors.join('\n\n')));
      }
      if (
        process.env.CI &&
        (typeof process.env.CI !== 'string' ||
          process.env.CI.toLowerCase() !== 'false') &&
        messages.warnings.length
      ) {
        console.log(
          chalk.yellow(
            '\nTreating warnings as errors because process.env.CI = true.\n' +
            'Most CI servers set it automatically.\n'
          )
        );
        return reject(new Error(messages.warnings.join('\n\n')));
      }

      const resolveArgs = {
        stats,
        warnings: messages.warnings
      };

      return resolve(resolveArgs);
    });
  });
}

bundle();
