import * as core from "@actions/core";
import {run_prechecks} from "./prechecks.js";
import {Octokit} from "@octokit/core";
import Authenticator from "./authenticator.js";
import EventParser from "./eventParser.js";

export default class Main
{
    private static _octokit: Octokit;
    private static _pr: any;

    public static async run()
    {
        run_prechecks();

        // Authenticate
        const owner = EventParser.GetOwner().login;
        const repo = EventParser.GetRepository().name;
        this._octokit = await Authenticator.GetOctokit(owner, repo);
    }
}

// Used implicitly via "@github/local-action"
export function run() {
    Main.run().catch(err => core.error(err));
}