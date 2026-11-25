// Publish the locally built application with GitHub CLI authentication.
// Credentials are handled by gh; this script never reads or prints tokens.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const root = path.resolve(__dirname, '..');
const repo = 'jinying0218/ColorLens';
const version = 'v1.0.0';
function gh(args, input) {
    return cp.execFileSync('gh', args, {cwd: root, input, encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe'], timeout: 180000});
}
try {
    const details = JSON.parse(gh(['api', `repos/${repo}`]));
    if (details.size === 0) {
        // GitHub requires an initial branch before a release can be created.
        const payload = {
            message: 'Add project overview and release installation instructions',
            content: fs.readFileSync(path.join(root, 'README.md')).toString('base64'),
            branch: 'main',
            committer: {name: 'jinying0218', email: 'jinying0218@users.noreply.github.com'},
            author: {name: 'jinying0218', email: 'jinying0218@users.noreply.github.com'}
        };
        gh(['api', '--method', 'PUT', `repos/${repo}/contents/README.md`, '--input', '-'], JSON.stringify(payload));
        console.log('Created initial README for release hosting.');
    }
    let exists = false;
    try { gh(['release', 'view', version, '--repo', repo]); exists = true; } catch {}
    if (!exists) {
        gh(['release', 'create', version, '--repo', repo, '--target', 'main',
            '--title', `ColorLens ${version}`, '--notes-file', 'RELEASE_NOTES.md']);
        console.log('Created release ' + version);
    }
    for (const name of ['ColorLens-1.0.0-macOS-arm64.zip', 'ColorLens-1.0.0-source.zip', 'SHA256SUMS.txt']) {
        gh(['release', 'upload', version, path.join('dist', name), '--repo', repo, '--clobber']);
        console.log('Uploaded ' + name);
    }
    console.log(gh(['release', 'view', version, '--repo', repo, '--json', 'url,assets']));
} catch (error) {
    console.error(String(error.stderr || error.message).slice(0, 1600));
    process.exitCode = 1;
}
