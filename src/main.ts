import * as core from "@actions/core";
import {run_prechecks} from "./prechecks.js";
import {Octokit} from "@octokit/core";
import Authenticator from "./authenticator.js";
import EventParser from "./eventParser.js";
import State from "./state.js";
import type {PullRequest, Repository} from "@octokit/webhooks-types";

export default class Main
{
    private static _octokit: Octokit;
    private static _repo: Repository;
    private static _pr: PullRequest;
    private static _userHasPerms: boolean;

    public static async run()
    {
        run_prechecks();

        // Authenticate
        this._repo = EventParser.GetRepository();
        this._pr = EventParser.GetPullRequest();
        this._octokit = await Authenticator.GetOctokit(this._repo.owner.login, this._repo.name);

        // Verify state
        this._userHasPerms = State.GetUserHasPerms(this._repo, this._pr.user.login, this._octokit);
    }
}

// Used implicitly via "@github/local-action"
export function run() {
    Main.run().catch(err => core.error(err));
}