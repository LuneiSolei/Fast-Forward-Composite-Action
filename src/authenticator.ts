import {createAppAuth} from "@octokit/auth-app";
import {Octokit} from "@octokit/core";

export default class Authenticator {
    private static _octokit: Octokit;

    public static get Octokit(): Octokit
    {
        if (!this._octokit) {
            this._octokit = new Octokit({
                authStrategy: createAppAuth,
                auth: {
                    appId: process.env.APP_CLIENT_ID,
                    privateKey: process.env.APP_PRIVATE_KEY
                }
            })
        }

        return this._octokit;
    }
}