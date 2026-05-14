import * as core from "@actions/core";

export function run_prechecks(): void {
    let isFailed: boolean = false;
    const options: core.InputOptions = {
        required: true,
        trimWhitespace: true
    }

    // Ensure comment input is valid
    const comment: string = core.getInput("comment", options);
    switch (comment) {
        case "always":
        case "on-error":
        case "never":
            break;
        default:
            core.setFailed(`Invalid value '${comment}' for workflow input 'comment'`);
            isFailed = true;
    }

    // Ensure github_token is set
    const githubToken: string = core.getInput("github_token", options);
    if (githubToken.length === 0)
    {
        core.setFailed(`Invalid value for workflow input 'github_token'.`);
        isFailed = true;
    }

    // Ensure auto_merge input is valid
    const autoMerge: boolean = core.getBooleanInput("auto_merge", options);
    if (typeof autoMerge != "boolean")
    {
        core.setFailed(`Invalid value '${autoMerge}' workflow input 'auto_merge'.`);
        isFailed = true;
    }

    // Ensure we're running via GitHub Actions
    if (!process.env.GITHUB_EVENT_PATH)
    {
        core.setFailed("GITHUB_EVENT_PATH environment variable not set. This script is intended to be run within a "
            + "GitHub Actions workflow.");
        isFailed = true;
    }

    core.debug(`GITHUB_ENV: ${process.env.GITHUB_ENV}`);
    core.debug(`GITHUB_EVENT_PATH: ${process.env.GITHUB_EVENT_PATH}`);

    if (isFailed) {
        process.exit(1);
    }

    core.summary.addRaw("Prechecks complete successfully.")
}