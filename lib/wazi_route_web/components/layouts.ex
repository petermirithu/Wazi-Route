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
      class="fixed -top-24 left-5 z-50 rounded-lg bg-accent px-5 py-3 font-semibold text-accent-content shadow-xl focus:top-5"
    >
      Skip to content
    </a>

    <div class="min-h-dvh">
      <div class="wazi-kitenge-border h-1.5" aria-hidden="true"></div>
      <header class="relative z-20 border-b border-base-300/70 bg-base-100/95 backdrop-blur-lg">
        <nav
          aria-label="Main navigation"
          class="mx-auto flex min-h-20 max-w-[1440px] items-center justify-between gap-4 px-5 sm:px-8 lg:px-12"
        >
          <a
            id="nav-brand"
            href={if(@current_scope && @current_scope.user, do: ~p"/dashboard", else: ~p"/")}
            aria-label="Wazi Route home"
            class="inline-flex shrink-0 items-center gap-2.5"
          >
            <img
              src={~p"/images/wazi-mark.png"}
              alt=""
              width="166"
              height="172"
              class="h-11 w-11 object-contain mix-blend-multiply"
            />
            <img
              src={~p"/images/wazi-wordmark.png"}
              alt="Wazi Route"
              width="280"
              height="43"
              class="h-auto w-30 object-contain mix-blend-multiply sm:w-36"
            />
          </a>

          <div class="hidden items-center gap-8 lg:flex">
            <%= if @current_scope && @current_scope.user do %>
              <.link
                navigate={~p"/dashboard"}
                class="text-sm font-semibold text-primary transition-colors hover:text-secondary"
              >Workspace</.link>
              <a href={~p"/"} class="text-sm font-medium transition-colors hover:text-secondary">Discover Wazi</a>
            <% else %>
              <a
                href={~p"/" <> "#why-wazi"}
                class="text-sm font-medium transition-colors hover:text-secondary"
              >Why Wazi</a>
              <a
                href={~p"/" <> "#how-it-works"}
                class="text-sm font-medium transition-colors hover:text-secondary"
              >How it works</a>
              <a
                href={~p"/" <> "#our-story"}
                class="text-sm font-medium transition-colors hover:text-secondary"
              >Our story</a>
            <% end %>
          </div>

          <div class="flex items-center gap-2 sm:gap-3">
            <%= if @current_scope && @current_scope.user do %>
              <details id="profile-menu" class="group relative">
                <summary class="flex min-h-12 cursor-pointer list-none items-center gap-3 rounded-full border border-base-300 bg-base-100 py-1.5 pr-2 pl-1.5 transition hover:border-secondary hover:shadow-md [&::-webkit-details-marker]:hidden">
                  <span class="flex size-9 items-center justify-center rounded-full bg-primary text-xs font-bold uppercase text-primary-content">
                    {String.first(@current_scope.user.first_name)}{String.first(
                      @current_scope.user.last_name
                    )}
                  </span>
                  <span class="hidden max-w-32 truncate text-sm font-semibold text-primary sm:block">{@current_scope.user.first_name}</span>
                  <.icon
                    name="hero-chevron-down"
                    class="mr-1 size-4 text-base-content/50 transition group-open:rotate-180"
                  />
                  <span class="sr-only">Open profile menu</span>
                </summary>
                <div class="absolute right-0 z-30 mt-3 w-64 overflow-hidden rounded-2xl border border-base-300 bg-base-100 shadow-2xl">
                  <div class="border-b border-base-300 bg-base-200 px-5 py-4">
                    <p class="truncate text-sm font-bold text-primary">
                      {@current_scope.user.first_name} {@current_scope.user.last_name}
                    </p>
                    <p class="mt-1 truncate text-xs text-base-content/55">
                      {@current_scope.user.email}
                    </p>
                  </div>
                  <div class="p-2">
                    <.link
                      navigate={~p"/dashboard"}
                      class="flex min-h-11 items-center gap-3 rounded-xl px-3 text-sm font-semibold text-primary transition hover:bg-base-200"
                    >
                      <.icon name="hero-squares-2x2" class="size-5 text-secondary" /> Workspace
                    </.link>
                    <a
                      href={~p"/"}
                      class="flex min-h-11 items-center gap-3 rounded-xl px-3 text-sm font-semibold text-primary transition hover:bg-base-200"
                    >
                      <.icon name="hero-globe-alt" class="size-5 text-secondary" /> Discover Wazi
                    </a>
                    <.link
                      navigate={~p"/profile"}
                      class="flex min-h-11 items-center gap-3 rounded-xl px-3 text-sm font-semibold text-primary transition hover:bg-base-200"
                    >
                      <.icon name="hero-user-circle" class="size-5 text-secondary" /> Profile
                    </.link>
                    <.link
                      href={~p"/users/log-out"}
                      method="delete"
                      class="flex min-h-11 items-center gap-3 rounded-xl px-3 text-sm font-semibold text-error transition hover:bg-error/10"
                    >
                      <.icon name="hero-arrow-right-start-on-rectangle" class="size-5" /> Log out
                    </.link>
                  </div>
                </div>
              </details>
            <% else %>
              <.link
                id="sign-in"
                href={~p"/users/log-in"}
                class="inline-flex min-h-11 items-center rounded-lg px-3 text-sm font-semibold hover:bg-base-200"
              >Log in</.link>
              <.link
                id="sign-up"
                href={~p"/users/register"}
                class="inline-flex min-h-11 items-center gap-2 rounded-lg bg-primary px-4 text-sm font-semibold text-primary-content transition hover:-translate-y-0.5 hover:bg-secondary hover:shadow-lg motion-reduce:transform-none"
              >
                Join Wazi <.icon name="hero-arrow-up-right" class="size-4" />
              </.link>
            <% end %>
          </div>
        </nav>
      </header>

      <main id="main-content" tabindex="-1">{render_slot(@inner_block)}</main>

      <footer class="wazi-pattern text-primary-content">
        <div class="mx-auto grid max-w-[1440px] gap-10 px-5 py-12 sm:px-8 lg:grid-cols-[1fr_auto] lg:px-12 lg:py-16">
          <div>
            <a
              href={~p"/"}
              aria-label="Wazi Route home"
              class="inline-flex items-center gap-3 rounded-lg bg-base-100 px-4 py-3"
            >
              <img
                src={~p"/images/wazi-mark.png"}
                alt=""
                width="166"
                height="172"
                class="h-10 w-10 object-contain mix-blend-multiply"
              />
              <img
                src={~p"/images/wazi-wordmark.png"}
                alt="Wazi Route"
                width="280"
                height="43"
                class="h-auto w-32 mix-blend-multiply"
              />
            </a>
            <p class="mt-5 max-w-md text-sm leading-7 text-primary-content/75">
              Road choices shaped around your car, your comfort, and the streets you drive every day.
            </p>
          </div>
          <div class="flex flex-wrap items-end gap-x-8 gap-y-3 text-sm font-medium">
            <a href={~p"/" <> "#why-wazi"} class="hover:text-accent">Why Wazi</a>
            <a href={~p"/" <> "#how-it-works"} class="hover:text-accent">How it works</a>
            <a href="#main-content" class="inline-flex items-center gap-2 hover:text-accent">Back to top
            <.icon name="hero-arrow-up" class="size-4" /></a>
          </div>
        </div>
        <div class="border-t border-primary-content/15 px-5 py-5 text-center text-xs text-primary-content/60">
          Built in Nairobi, for the roads that shape our days.
        </div>
      </footer>
    </div>

    <dialog
      id="launch-dialog"
      class="m-auto max-h-[calc(100dvh_-_2rem)] w-[calc(100%_-_2rem)] max-w-[480px] overflow-y-auto rounded-2xl border border-base-300 bg-base-100 p-0 text-base-content shadow-2xl backdrop:bg-neutral/70 backdrop:backdrop-blur-sm"
      aria-labelledby="launch-title"
      aria-describedby="launch-description"
    >
      <div class="wazi-pattern px-7 pt-6 pb-10 text-primary-content">
        <form method="dialog" class="flex justify-end">
          <.button
            id="close-launch-dialog"
            class="inline-flex size-11 cursor-pointer items-center justify-center rounded-full border border-primary-content/30 hover:bg-primary-content/10"
            aria-label="Close notice"
            autofocus
          >
            <.icon name="hero-x-mark" class="size-5" />
          </.button>
        </form>
        <p class="mt-3 text-xs font-bold uppercase tracking-[0.18em] text-accent">The road ahead</p>
        <h2 id="launch-title" class="mt-3 text-4xl font-bold">We're getting ready.</h2>
      </div>
      <div class="p-7">
        <p id="launch-description" class="text-sm leading-7 text-base-content/75">
          Route planning is still in development, beginning with Nairobi's northwest. Create an account today and follow the journey as coverage grows.
        </p>
        <form method="dialog" class="mt-7">
          <.button class="inline-flex min-h-13 w-full cursor-pointer items-center justify-center gap-3 rounded-lg bg-secondary px-5 py-3 text-sm font-semibold text-secondary-content transition hover:bg-primary">Got it
          <.icon name="hero-check" class="size-4" /></.button>
        </form>
      </div>
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
