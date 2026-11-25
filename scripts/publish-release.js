// Publish the locally built application with GitHub CLI authentication.
// Credentials are handled by gh; this script never reads or prints tokens.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const crypto = require('node:crypto');
const root = path.resolve(__dirname, '..');
const repo = 'jinying0218/ColorLens';
const appVersion = fs.readFileSync(path.join(root, 'Resources/Info.plist'), 'utf8')
    .match(/CFBundleShortVersionString<\/key><string>([^<]+)<\/string>/)?.[1];
if (!appVersion || !/^\d+\.\d+\.\d+$/.test(appVersion)) throw new Error('Invalid app version');
const version = 'v' + appVersion;
function gh(args, input) {
    return cp.execFileSync('gh', args, {cwd: root, input, encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe'], timeout: 900000});
}
try {
    const head = cp.execFileSync('git', ['rev-parse', 'HEAD'], {cwd: root, encoding: 'utf8'}).trim();
    const remote = JSON.parse(gh(['api', `repos/${repo}/commits/main`]));
    if (remote.sha !== head) throw new Error('Push the latest source to main before publishing.');
    let exists = false;
    try { gh(['release', 'view', version, '--repo', repo]); exists = true; } catch {}
    if (!exists) {
        gh(['release', 'create', version, '--repo', repo, '--target', 'main',
            '--title', `ColorLens ${version}`, '--notes-file', 'RELEASE_NOTES.md', '--draft']);
        console.log('Created release ' + version);
    }
    const release = JSON.parse(gh(['release', 'view', version, '--repo', repo, '--json', 'assets']));
    for (const name of [`ColorLens-${appVersion}-macOS-arm64.zip`, 'SHA256SUMS.txt']) {
        const digest = 'sha256:' + crypto.createHash('sha256').update(fs.readFileSync(path.join(root, 'dist', name))).digest('hex');
        if (release.assets.some(asset => asset.name === name && asset.state === 'uploaded' && asset.digest === digest)) {
            console.log('Already uploaded ' + name);
            continue;
        }
        gh(['release', 'upload', version, path.join('dist', name), '--repo', repo, '--clobber']);
        console.log('Uploaded ' + name);
    }
    gh(['release', 'edit', version, '--repo', repo, '--draft=false', '--latest']);
    console.log(gh(['release', 'view', version, '--repo', repo, '--json', 'url,assets']));
} catch (error) {
    console.error(String(error.stderr || error.message).slice(0, 1600));
    process.exitCode = 1;
}
