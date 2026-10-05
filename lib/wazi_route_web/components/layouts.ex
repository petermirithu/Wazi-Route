defmodule WaziRouteWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use WaziRouteWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <a
      href="#main-content"
      class="fixed -top-24 left-6 z-50 rounded-field bg-base-100 p-4 focus:top-4"
    >Skip to content</a>
    <div
      id="site-frame"
      class="mx-auto w-full max-w-[1360px] rounded-box border border-base-300 bg-base-100 px-3 sm:px-6 lg:px-8"
    >
      <header>
        <nav
          aria-label="Main navigation"
          class="flex min-h-25 flex-wrap items-center justify-between gap-3 py-4 lg:flex-nowrap lg:gap-6 lg:py-0"
        >
          <a
            id="nav-brand"
            href={~p"/"}
            aria-label="Wazi Route home"
            class="inline-flex shrink-0 items-center gap-1.5 sm:gap-2.5"
          >
            <img
              src={~p"/images/wazi-mark.png"}
              alt=""
              width="166"
              height="172"
              class="h-auto w-8 object-contain mix-blend-multiply sm:w-10 xl:w-12"
            />
            <img
              src={~p"/images/wazi-wordmark.png"}
              alt="Wazi Route"
              width="280"
              height="43"
              class="h-auto w-23 object-contain mix-blend-multiply sm:w-30 xl:w-36"
            />
          </a>
          <div class="order-3 flex w-full items-center justify-center gap-5 border-t border-base-300 pt-2.5 sm:gap-7 lg:order-none lg:w-auto lg:border-0 lg:pt-0">
            <a
              href={~p"/" <> "#why-wazi"}
              class="inline-flex min-h-11 items-center text-xs font-medium underline-offset-6 hover:underline xl:text-[13px]"
            >The difference</a>
            <a
              href={~p"/" <> "#how-it-works"}
              class="inline-flex min-h-11 items-center text-xs font-medium underline-offset-6 hover:underline xl:text-[13px]"
            >How it works</a>
            <a
              href={~p"/" <> "#our-story"}
              class="inline-flex min-h-11 items-center text-xs font-medium underline-offset-6 hover:underline xl:text-[13px]"
            >Our story</a>
          </div>
          <div class="flex items-center gap-2 sm:gap-4 xl:gap-5">
            <.button
              id="sign-in"
              href={~p"/" <> "#coming-soon"}
              data-coming-soon
              class="inline-flex min-h-11 items-center text-xs font-medium underline-offset-6 hover:underline xl:text-[13px]"
            >Sign in</.button>
            <.button
              id="sign-up"
              href={~p"/" <> "#coming-soon"}
              data-coming-soon
              class="inline-flex min-h-11 items-center justify-center gap-2 rounded-field bg-neutral px-3 py-2.5 text-xs font-medium text-neutral-content transition-colors hover:bg-secondary hover:text-secondary-content motion-reduce:transition-none sm:px-4 xl:text-[13px]"
            >
              Sign up <.icon name="hero-arrow-up-right" class="size-4" />
            </.button>
          </div>
        </nav>
      </header>

      <main id="main-content" tabindex="-1">{render_slot(@inner_block)}</main>

      <footer class="flex flex-wrap items-center justify-between gap-4 py-7 lg:flex-nowrap lg:gap-6 lg:pt-9">
        <a href={~p"/"} aria-label="Wazi Route home" class="inline-flex shrink-0 items-center gap-2.5">
          <img
            src={~p"/images/wazi-mark.png"}
            alt=""
            width="166"
            height="172"
            class="h-auto w-9 object-contain mix-blend-multiply"
          />
          <img
            src={~p"/images/wazi-wordmark.png"}
            alt="Wazi Route"
            width="280"
            height="43"
            class="h-auto w-28 object-contain mix-blend-multiply"
          />
        </a>
        <p class="order-3 w-full text-xs text-base-content/75 lg:order-none lg:w-auto">
          Made for the way you drive.
        </p>
        <a
          href="#main-content"
          class="inline-flex min-h-11 items-center gap-3 text-xs font-medium underline-offset-6 hover:underline"
        >Back to top <.icon name="hero-arrow-up" class="size-4" /></a>
      </footer>
      <details id="install-help" class="mb-6 rounded-box bg-base-200 px-5 py-3 [&[hidden]]:hidden">
        <summary class="min-h-11 cursor-pointer py-3 text-sm font-medium text-primary">
          Install Wazi Route on your phone
        </summary>
        <div class="grid gap-5 pt-3 pb-4 text-sm leading-7 sm:grid-cols-2">
          <p id="ios-install-help">
            <strong class="font-semibold">iPhone or iPad</strong><br />Open this site in Safari, tap Share, then Add to Home Screen. Keep Open as Web App enabled if shown, then tap Add.
          </p>
          <p id="android-install-help">
            <strong class="font-semibold">Android</strong><br />Open this site in Chrome. Use Install below when available, or choose Install app / Add to Home screen from the browser menu.
          </p>
        </div>
        <.button
          id="pwa-install"
          hidden
          class="mb-3 inline-flex min-h-12 items-center gap-3 rounded-field bg-neutral px-5 py-3 text-sm font-semibold text-neutral-content hover:bg-secondary [&[hidden]]:hidden"
        >
          <.icon name="hero-arrow-down-tray" class="size-5" /> Install Wazi Route
        </.button>
        <p id="pwa-install-status" role="status" class="text-xs leading-6 text-base-content/75"></p>
      </details>
    </div>

    <dialog
      id="launch-dialog"
      class="m-auto max-h-[calc(100dvh_-_2rem)] w-[calc(100%_-_2rem)] max-w-[460px] overflow-y-auto rounded-box border border-base-300 bg-base-100 p-7 text-base-content shadow-2xl backdrop:bg-neutral/60 backdrop:backdrop-blur-sm"
      aria-labelledby="launch-title"
      aria-describedby="launch-description"
    >
      <form method="dialog" class="flex justify-end">
        <.button
          id="close-launch-dialog"
          class="inline-flex size-11 cursor-pointer items-center justify-center rounded-field hover:bg-base-200"
          aria-label="Close notice"
          autofocus
        >
          <.icon name="hero-x-mark" class="size-5" />
        </.button>
      </form>
      <img
        src={~p"/images/wazi-mark.png"}
        alt=""
        width="166"
        height="172"
        class="mb-5 w-14 mix-blend-multiply"
      />
      <h2 id="launch-title" class="text-3xl font-semibold">Coming soon.</h2>
      <p id="launch-description" class="mt-4 text-sm leading-7 text-base-content/70">
        We're building Wazi Route, starting with a Nairobi northwest pilot. Sign in, sign up, and route planning aren't available yet. No account details are being collected.
      </p>
      <form method="dialog" class="mt-7">
        <.button class="inline-flex min-h-13 w-full cursor-pointer items-center justify-center gap-3 rounded-field bg-neutral px-5 py-3 text-sm font-medium text-neutral-content transition-colors hover:bg-secondary hover:text-secondary-content motion-reduce:transition-none">Got it
        <.icon name="hero-check" class="size-4" /></.button>
      </form>
    </dialog>
    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
