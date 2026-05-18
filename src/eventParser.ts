import * as fs from "node:fs";
import path from "path";
import type {
    IssueCommentCreatedEvent,
    IssueCommentEditedEvent, PullRequest,
    PullRequestOpenedEvent, Repository, User,
    WebhookEvent
} from "@octokit/webhooks-types";
import * as core from "@actions/core";
import {ValidEvent} from "./validEvent.js";

export default class EventParser {
    private static _event: PullRequestOpenedEvent | IssueCommentCreatedEvent | IssueCommentEditedEvent;
    private static _eventType: ValidEvent;

    public static get Event(): PullRequestOpenedEvent | IssueCommentCreatedEvent | IssueCommentEditedEvent {
        if (!this._event)
        {
            // Resolve event as a WebhookEvent
            const eventPath: string = process.env.GITHUB_EVENT_PATH as string;
            const raw: string = fs.readFileSync(path.resolve(eventPath), "utf8");
            const parsedEvent = JSON.parse(raw);

            if (parsedEvent.pull_request != undefined && parsedEvent.action == "opened")
            {
                this._event = parsedEvent as PullRequestOpenedEvent;
                this._eventType = ValidEvent.PullRequestOpened;
            }
            else if (parsedEvent.comment != undefined)
            {
                if (parsedEvent.action == "created") {
                    this._event = parsedEvent as IssueCommentCreatedEvent;
                    // TODO: Validate that this is a comment on a PR, not a plain issue
                    this._eventType = ValidEvent.IssueCommentCreated;
                }
                else if (parsedEvent.action == "edited") {
                    this._event = parsedEvent as IssueCommentEditedEvent;
                    this._eventType = ValidEvent.IssueCommentEdited;
                }
            }
            else
            {
                core.error("Event is neither a pull request or issue comment: ", parsedEvent);
            }

            // Debug logging
            if (process.env.ACTIONS_STEP_DEBUG) {
                core.debug(`Received '${this._eventType.toString()}Event': ${JSON.stringify(parsedEvent, null, 2)}`);
            }
        }

        return this._event;
    }

    public static GetPullRequest(): PullRequest
    {
        switch (this._eventType) {
            case ValidEvent.PullRequestOpened:
                return (this.Event as PullRequestOpenedEvent).pull_request;
            // TODO: case this.isIssueCommentCreated(this.Event):
            //     return this.Event.repository
            // case this.isIssueCommentEdited(this.Event):
            // case ValidEvent.IssueCommentCreated:
            //     (this.Event as IssueCommentCreatedEvent).issue.pull_request
            default:
                core.error(`Pull request could not be found on event '${this.Event}'`);
                return {} as PullRequest;
        }
    }

    private constructor() {}

    public static GetOwner(): User
    {
        return this.Event.repository.owner;
    }

    public static GetRepository(): Repository
    {
        return this.Event.repository;
    }
}