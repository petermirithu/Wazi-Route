const {test} = require('node:test')
const assert = require('node:assert/strict')
const {readFileSync} = require('node:fs')
const {resolve} = require('node:path')
const vm = require('node:vm')
const root = resolve(__dirname, '../..')

function worker({offline = false, initial = {}} = {}) {
  const listeners = {}
  const stores = new Map(Object.entries(initial))
  let claimed = false
  const caches = {
    keys: async () => [...stores.keys()],
    delete: async name => stores.delete(name),
    open: async name => {
      if (!stores.has(name)) stores.set(name, new Map())
      const store = stores.get(name)
      return {
        addAll: async urls => urls.forEach(url => store.set(url, new Response(`cached:${url}`))),
        match: async url => store.get(url)?.clone(),
      }
    },
  }
  vm.runInNewContext(readFileSync(resolve(root, 'priv/static/sw.js'), 'utf8'), {
    URL, Response, caches,
    fetch: async () => {
      if (offline) throw new TypeError('Offline')
      return new Response('fresh network response')
    },
    self: {
      location: {origin: 'https://wazi.example'},
      clients: {claim: async () => { claimed = true }},
      addEventListener: (name, handler) => { listeners[name] = handler },
    },
  })
  return {
    stores,
    claimed: () => claimed,
    lifecycle: async name => {
      let pending
      listeners[name]({waitUntil: promise => { pending = promise }})
      await pending
    },
    request: async (path, {method = 'GET', mode = 'navigate'} = {}) => {
      let response
      listeners.fetch({
        request: {url: new URL(path, 'https://wazi.example').href, method, mode},
        respondWith: promise => { response = promise },
      })
      return response
    },
  }
}

test('precache contains only real public files, never session pages or source bundles', async () => {
  const sw = worker()
  await sw.lifecycle('install')
  const cached = [...sw.stores.values()][0]
  assert(cached.has('/offline.html'))
  assert(!cached.has('/'))
  assert(!cached.has('/assets/js/landing.js'))
  assert(!cached.has('/assets/css/fonts.css'))
  for (const path of cached.keys()) assert(readFileSync(resolve(root, `priv/static${path}`)).length > 0)
})

test('activation removes only obsolete Wazi Route caches', async () => {
  const sw = worker({initial: {'wazi-route-pwa-v1': new Map(), 'another-app': new Map()}})
  await sw.lifecycle('install')
  await sw.lifecycle('activate')
  assert(!sw.stores.has('wazi-route-pwa-v1'))
  assert(sw.stores.has('another-app'))
  assert(sw.claimed())
})

test('offline navigation uses the anonymous fallback and cached public styles', async () => {
  const sw = worker({offline: true})
  await sw.lifecycle('install')
  assert.equal(await (await sw.request('/private-page')).text(), 'cached:/offline.html')
  assert.equal(await (await sw.request('/assets/css/app.css', {mode: 'cors'})).text(), 'cached:/assets/css/app.css')
})

test('online navigations and assets always use the network without caching responses', async () => {
  const sw = worker()
  await sw.lifecycle('install')
  assert.equal(await (await sw.request('/')).text(), 'fresh network response')
  assert.equal(await (await sw.request('/assets/css/app.css', {mode: 'cors'})).text(), 'fresh network response')
  assert(![...sw.stores.values()][0].has('/'))
})

test('API, LiveView, mutation, and foreign requests are not intercepted', async () => {
  const sw = worker({offline: true})
  for (const path of ['/api/routes', '/live/longpoll', 'https://example.net/data']) {
    assert.equal(await sw.request(path, {mode: 'cors'}), undefined)
  }
  assert.equal(await sw.request('/users', {method: 'POST'}), undefined)
})

test('evicted offline cache gives a controlled unavailable response', async () => {
  const sw = worker({offline: true})
  assert.equal((await sw.request('/')).status, 503)
})

function installUI({secure = true, iosStandalone = false} = {}) {
  const listeners = {}
  const elements = Object.fromEntries(['install-help', 'pwa-install', 'pwa-install-status'].map(id => [id, {hidden: false, textContent: ''}]))
  const registrations = []
  vm.runInNewContext(readFileSync(resolve(root, 'assets/js/pwa.js'), 'utf8'), {
    console,
    window: {
      isSecureContext: secure,
      matchMedia: () => ({matches: false, addEventListener() {}}),
      addEventListener: (name, handler) => { listeners[name] = handler },
    },
    navigator: {
      standalone: iosStandalone,
      serviceWorker: {register: (...args) => { registrations.push(args); return Promise.resolve() }},
    },
    document: {
      readyState: 'complete',
      getElementById: id => elements[id],
      addEventListener: (name, handler) => { listeners[name] = handler },
    },
  })
  return {listeners, elements, registrations}
}

test('secure origins register a root-scoped, revalidated worker', () => {
  const ui = installUI()
  assert.equal(ui.registrations[0][0], '/sw.js')
  assert.equal(ui.registrations[0][1].scope, '/')
  assert.equal(ui.registrations[0][1].updateViaCache, 'none')
  assert.equal(ui.elements['pwa-install'].hidden, true)
  assert.equal(ui.elements['install-help'].hidden, false)
})

test('insecure origins show HTTPS guidance and iOS standalone hides install help', () => {
  const insecure = installUI({secure: false})
  assert.equal(insecure.registrations.length, 0)
  assert.match(insecure.elements['pwa-install-status'].textContent, /HTTPS/)
  assert.equal(installUI({iosStandalone: true}).elements['install-help'].hidden, true)
})

test('Android native prompts are one-shot and dismissal keeps manual guidance available', async () => {
  const ui = installUI()
  let prompts = 0
  ui.listeners.beforeinstallprompt({
    preventDefault() {},
    prompt: async () => { prompts++ },
    userChoice: Promise.resolve({outcome: 'dismissed'}),
  })
  assert.equal(ui.elements['pwa-install'].hidden, false)
  const event = {target: {closest: () => ui.elements['pwa-install']}}
  await ui.listeners.click(event)
  await ui.listeners.click(event)
  assert.equal(prompts, 1)
  assert.equal(ui.elements['pwa-install'].hidden, true)
  assert.match(ui.elements['pwa-install-status'].textContent, /install later/)
  ui.listeners.appinstalled()
  ui.listeners['phx:page-loading-stop']()
  assert.equal(ui.elements['install-help'].hidden, true)
})
