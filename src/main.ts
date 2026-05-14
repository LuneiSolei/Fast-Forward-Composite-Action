import * as core from "@actions/core";

import {run_prechecks} from "./prechecks.js";
import {Octokit} from "@octokit/core";
import Authenticator from "./authenticator.js";
import get_pr from "./getPR.js";

export default class Main
{
    private static _octokit: Octokit;
    private static _pr: any;

    public static async run()
    {
        run_prechecks();
        this._octokit = Authenticator.Octokit
        this._pr = get_pr(this._octokit);
    }
}

// Used implicitly via "@github/local-action"
export function run() {
    Main.run().catch(err => core.error(err));
}