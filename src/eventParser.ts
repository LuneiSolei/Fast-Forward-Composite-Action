import * as fs from "node:fs";
import path from "path";
import type {
    IssueCommentCreatedEvent,
    IssueCommentEditedEvent, PullRequest,
    PullRequestOpenedEvent, Repository, User,
    WebhookEvent
} from "@octokit/webhooks-types";
import * as core from "@actions/core";

export type ValidEvent = PullRequestOpenedEvent | IssueCommentCreatedEvent | IssueCommentEditedEvent;

export default class EventParser {
    private static _event: WebhookEvent;

    public static get Event(): WebhookEvent {
        if (!this._event)
        {
            const eventPath: string = process.env.GITHUB_EVENT_PATH as string;
            const raw: string = fs.readFileSync(path.resolve(eventPath), "utf8");
            this._event = JSON.parse(raw) as WebhookEvent;

            if (process.env.ACTIONS_STEP_DEBUG) {
                switch (true) {
                    case this.isPullRequestOpened(this._event):
                        core.debug("Received 'PullRequestOpenedEvent'");
                        core.debug(JSON.stringify(this._event, null, 2));
                        break;
                    case this.isIssueCommentCreated(this._event):
                        core.debug("Received 'IssueCommentCreatedEvent'");
                        core.debug(JSON.stringify(this._event, null, 2));
                        break;
                    case this.isIssueCommentEdited(this._event):
                        core.debug("Received 'IssueCommentEditedEvent'");
                        core.debug(JSON.stringify(this._event, null, 2));
                        break;
                    default:
                        core.error("Event is neither a pull request or issue comment.");
                        core.debug(JSON.stringify(this._event, null, 2));
                }
            }
        }

        return this._event;
    }

    public static get PullRequest(): PullRequest
    {
        switch (true) {
            case this.isPullRequestOpened(this.Event):
                return this.Event.pull_request;
            // case this.isIssueCommentCreated(this.Event):
            //     return this.Event.repository
            // case this.isIssueCommentEdited(this.Event):
            default:
                core.error(`Pull request could not be found on event '${this.Event}'`)
                return {} as PullRequest;
        }
    }

    private constructor() {}

    public static GetOwner(): User
    {
        switch (true) {
            case this.isPullRequestOpened(this.Event):
                return this.Event.repository.owner;
            case this.isIssueCommentCreated(this.Event):
                return this.Event.repository.owner;
            case this.isIssueCommentEdited(this.Event):
                return this.Event.repository.owner;
            default:
                core.error(`Owner could not be found on event '${this.Event}'`);
                return {} as User;
        }
    }

    public static GetRepository(): Repository
    {
        switch (true) {
            case this.isPullRequestOpened(this.Event):
                return this.Event.repository;
            case this.isIssueCommentCreated(this.Event):
                return this.Event.repository;
            case this.isIssueCommentEdited(this.Event):
                return this.Event.repository;
            default:
                core.error(`Repository could not be found on event '${this.Event}'`);
                return {} as Repository;
        }
    }

    private static isPullRequestOpened(event: WebhookEvent): event is PullRequestOpenedEvent
    {
        const e: any = event as any;
        const isPullRequest: boolean = e.pull_request !== undefined;
        const isOpened: boolean = e.action === "opened";

        return e && isPullRequest && isOpened;
    }

    private static isIssueCommentCreated(event: WebhookEvent): event is IssueCommentCreatedEvent
    {
        const e: any = event as any;
        const isComment: boolean = e.comment !== undefined;
        const isCreated: boolean = e.action === "created";

        return e && isComment && isCreated;
    }

    private static isIssueCommentEdited(event: WebhookEvent): event is IssueCommentEditedEvent
    {
        const e: any = event as any;
        const isComment: boolean = e.comment !== undefined;
        const isEdited: boolean = e.action !== "edited";

        return e && isComment && isEdited;
    }
}