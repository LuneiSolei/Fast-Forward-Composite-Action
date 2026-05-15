import {Octokit} from "@octokit/core";
import {createAppAuth} from "@octokit/auth-app";
import * as core from "@actions/core";

export default class Authenticator {
    private static _octokit: Octokit;

    public static async GetOctokit(owner: string, repo: string): Promise<Octokit>
    {
        if (!this._octokit) {
            const APP_ID = process.env.APP_CLIENT_ID as string;
            const PRIVATE_KEY = process.env.APP_PRIVATE_KEY as string;

            // Create Octokit JWT
            const octokit = new Octokit({
                authStrategy: createAppAuth,
                auth: {
                    appId: APP_ID,
                    privateKey: PRIVATE_KEY
                }
            });

            // Find repo installation
            const { data: {id: installationId} } = await octokit.request(
                "GET /repos/{owner}/{repo}/installation",
                { owner, repo }
            );

            // Exchange installation ID for installation token
            const appAuth = createAppAuth({
                appId: APP_ID,
                privateKey: PRIVATE_KEY,
                installationId
            });
            const token = (await appAuth({type: "installation"})).token;
            if (!token) core.error("Failed to obtain installation token.");

            // Authenticate as app
            this._octokit = new Octokit({ auth: token });
        }

        return this._octokit;
    }
}