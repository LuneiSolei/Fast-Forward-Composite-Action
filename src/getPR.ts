import { Octokit } from "@octokit/core"
import EventParser, {type GitHubEvent} from "./eventParser.js";
import * as core from "@actions/core";
import type {PullRequest, PullRequestEvent} from "@octokit/webhooks-types";

export default function get_pr(octokit: Octokit): PullRequest {
    const event: GitHubEvent = EventParser.Event;
    if (EventParser.Event as PullRequestEvent) {
        core.info(JSON.stringify(event.payload.pull_request, null, 2));

        return event.payload.pull_request as PullRequest;
    } else {
        core.info("error!")

        return {} as PullRequest;
    }
}