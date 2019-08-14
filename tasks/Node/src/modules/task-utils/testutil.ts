import fs from 'fs';
import path from 'path';

import * as tl from 'azure-pipelines-task-lib/task';

export function getTestData(): any {
    try {
        const parentFileName = module.parent ? module.parent.filename : null;
        if (!parentFileName) {
            throw 'TestUtil: Expectation is that this function is called from a parent module.';
        }

        tl.debug(`TestUtil: Getting test data for module '${path.relative(process.cwd(), parentFileName)}'.`)

        const rootTestDataFilePath = path.dirname(parentFileName).replace(/\\out\\/gi, '\\src\\');
        const testDataFilePath = path.join(rootTestDataFilePath, 'testdata.json');

        tl.debug(`TestUtil: Getting test data from test file '${path.relative(process.cwd(), testDataFilePath)}'.`)
        const data = fs.readFileSync(testDataFilePath, 'utf8');

        return JSON.parse(data);
    }
    catch (error) {
        tl.error(error);
    }
}

export function writeTestLog(error: any): void {
    try {
        const parentFileName = module.parent ? module.parent.filename : null;
        if (!parentFileName) {
            throw 'TestUtil: Expectation is that this function is called from a parent module.';
        }

        tl.debug(`TestUtil: Writing test log for module '${path.relative(process.cwd(), parentFileName)}'.`)
        const testLogFilePath = path.join(path.dirname(parentFileName), 'testlog.json');

        tl.debug(`TestUtil: Writing test log to file '${path.relative(process.cwd(), testLogFilePath)}'.`)
        fs.writeFileSync(testLogFilePath, JSON.stringify(error, null, 2), 'utf8');
    }
    catch (error) {
        tl.error(error);
    }
}