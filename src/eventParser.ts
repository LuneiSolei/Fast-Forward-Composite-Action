import * as fs from "node:fs";
import path from "path";
import type { WebhookEvent } from "@octokit/webhooks-types";

export type GitHubEvent = Record<string, any>;

export default class EventParser {
    private static _event: WebhookEvent;

    public static get Event(): WebhookEvent {
        if (!this._event)
        {
            const eventPath: string = process.env.GITHUB_EVENT_PATH as string;
            const raw: string = fs.readFileSync(path.resolve(eventPath), "utf8");
            this._event = JSON.parse(raw) as WebhookEvent;
        }

        return this._event;
    }

    private constructor() {}
}