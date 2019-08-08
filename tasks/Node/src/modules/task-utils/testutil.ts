import fs from 'fs';
import path from 'path';
import util from 'util';

import * as tl from 'azure-pipelines-task-lib/task';

export async function getTestData(): Promise<any> {
    try {
        const parentFileName = module.parent ? module.parent.filename : null;
        if (!parentFileName) {
            throw 'TestUtil: Expectation is that this function is called from a parent module.';
        }

        tl.debug(`TestUtil: Getting test data for module '${path.relative(process.cwd(), parentFileName)}'.`)
        const testDataFilePath = path.join(path.dirname(parentFileName), 'testdata.json');

        tl.debug(`TestUtil: Getting test data from test file '${path.relative(process.cwd(), testDataFilePath)}'.`)
        const fsReadFile = util.promisify(fs.readFile);
        const data = await fsReadFile(testDataFilePath, 'utf8');

        return JSON.parse(data);
    }
    catch (error) {
        tl.error(error);
    }
}

export async function writeTestLog(error: any): Promise<any> {
    try {
        const parentFileName = module.parent ? module.parent.filename : null;
        if (!parentFileName) {
            throw 'TestUtil: Expectation is that this function is called from a parent module.';
        }

        tl.debug(`TestUtil: Writing test log for module '${path.relative(process.cwd(), parentFileName)}'.`)
        const testLogFilePath = path.join(path.dirname(parentFileName), 'testlog.json');

        tl.debug(`TestUtil: Writing test log to file '${path.relative(process.cwd(), testLogFilePath)}'.`)
        const fsWriteFile = util.promisify(fs.writeFile);
        await fsWriteFile(testLogFilePath, JSON.stringify(error, null, 2), 'utf8');
    }
    catch (error) {
        tl.error(error);
    }
}