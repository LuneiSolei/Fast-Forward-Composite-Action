import type {Repository} from "@octokit/webhooks-types";
import type {Octokit} from "@octokit/core";

export default class State
{
    private static _userHasPerms: boolean;

    public static GetUserHasPerms(repo: Repository, username: string, octokit: Octokit)
    {
        if (this._userHasPerms) return this._userHasPerms;

        // Check if user is owner
        if (repo.owner.login == username) {
            this._userHasPerms = true;
        } else {
            // Different repo types have varying levels of permissible users
            octokit.graphql(`
                query($owner: String!, $repoName: String!, $username: String!) {
                    repository(owner: $owner, name: $repoName) {
                        collaborators(login: $username) {
                            nodes {
                                login
                            }
                        }
                    }
                }
            `, {owner: repo.owner.login, repoName: repo.name, username});
        }

        return this._userHasPerms;
    }
}