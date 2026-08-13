# Product images (Active Storage on Disk, no external object storage)

**Status:** backlog.

## Goal

An admin uploads one photo per product at `/admin/products`. The waiter can show
the customer what the product looks like from the product browser
(`app/views/orders/_product_browser.html.erb`), which today paints a grey 64px
tile with a ☕ emoji in exactly the spot the photo belongs.

Constraint from the operator: **no new paid storage service**. Use what Rails
ships with, unless hosting makes that impossible.

## Storage decision: Active Storage `Disk` on a mounted volume

Verified state of the repo today:

- Active Storage is **not installed**: no `active_storage_blobs` /
  `active_storage_attachments` / `active_storage_variant_records` in `db/schema.rb`.
- `config/environments/production.rb:25` already sets
  `config.active_storage.service = :local`, i.e. the `Disk` service rooted at
  `Rails.root.join("storage")` (`config/storage.yml`).
- `Dockerfile:19` already installs `libvips`, so variants need no image changes.
- `gem "image_processing", "~> 1.2"` is commented out at `Gemfile:3`.
- `config/deploy.yml` already mounts `may_store_storage:/rails/storage`, so a
  **Kamal deploy needs zero storage work**. Disk files survive redeploys.

Sizing: a cafe menu is on the order of 100–300 products. One ~1600px original
plus two WebP variants at ~150KB each lands around **50–100 MB total**. That is
noise on any volume.

### Railway

Railway supports both, and Disk is still the pick:

- **Volumes**: attach a volume to the web service, mount at `/rails/storage`.
  Billed per GB-minute on actual usage, so ~100 MB costs effectively nothing.
  Backups (manual and automated) are supported.
  Hard constraint: **replicas cannot be used with a volume** - one container only.
  For a single-store-per-server app that is already the shape we run.
- **Railway Buckets**: private S3-compatible object storage, per-environment
  credentials, 1 TB workspace cap. This is the escape hatch if we ever need
  replicas, not the starting point. It is another billed resource and another
  set of credentials.

So: **Disk + volume on either host.** The only thing that forces a change is
horizontal scaling of the web process.

### If we ever need R2 after all

`~/code/mine/doctors` already solved this and the port is mechanical:

- `config/storage.yml` gets a `cloudflare:` service with
  `service: TenantS3`, `region: auto`, `http_proxy: ~`, endpoint
  `https://$CLOUDFLARE_R2_ACCOUNT_ID.r2.cloudflarestorage.com`.
- `lib/active_storage/service/tenant_s3_service.rb` subclasses
  `ActiveStorage::Service::S3Service` and prefixes every key with
  `<subdomain>/attachments/...`, caching the prefix in blob metadata.
- Add `aws-sdk-s3`, flip `config.active_storage.service` in production.

Nothing in this plan blocks that swap: it is one config line plus a
`bin/rails active_storage:migrate` style copy of existing blobs.

## Work

### 1. Install Active Storage

```
bin/rails active_storage:install
bin/rails db:migrate
```

Uncomment `gem "image_processing", "~> 1.2"` in `Gemfile`. `libvips` is already
in the image; add it to the local dev setup notes (`brew install vips`).

In `config/environments/production.rb`, add:

```ruby
config.active_storage.resolve_model_to_route = :rails_storage_proxy
```

Proxy mode serves bytes through the app with cache headers, instead of a
redirect to a signed, short-lived URL. On Disk that is the sane default and it
keeps image URLs stable enough to be cached by the browser and by Cloudflare in
front of the app.

### 2. Model

```ruby
class Product < ApplicationRecord
  has_one_attached :image do |attachable|
    attachable.variant :thumb, resize_to_fill: [ 160, 160 ], format: :webp, preprocessed: true
    attachable.variant :card,  resize_to_fill: [ 480, 480 ], format: :webp, preprocessed: true
  end

  validate :image_is_a_reasonable_photo
end
```

Validation rules (plain Ruby, no gem, matching the "no external gems" habit):

- content type in `%w[image/jpeg image/png image/webp image/heic]` (phone
  cameras hand you HEIC; libvips reads it)
- byte size `<= 10.megabytes`
- error messages from `config/locales/es.yml`

`preprocessed: true` builds the variants in a background job on attach, so the
waiter never waits on a first-request transform mid-service. Solid Queue runs
in Puma already (`SOLID_QUEUE_IN_PUMA: true` in `config/deploy.yml`).

Tenant safety note: blob URLs are signed globally, not scoped by
`Current.store`. That is acceptable here (a product photo is not secret), but it
is worth knowing that a signed URL from store A is not rejected by store B.

### 3. Admin form

`app/views/admin/products/_form.html.erb`: a file field plus a preview of the
current image and a "remove image" checkbox (`f.hidden_field :image, value: ""`
is not it - use `product.image.purge_later` driven by a
`remove_image` virtual attribute, which keeps the update path a single
`@product.update`).

Herb rules that bite here:

- the file input needs `autocomplete="off"`
- the remove-image control is a `<label>` + `check_box_tag`, no `<div>` inside
  the `<label>`; use `<span class="block ...">`
- any "clear" affordance that only fires a Stimulus action is
  `tag.button ... type: "button"`, never `<a href="#">`

Permit `:image` and `:remove_image` in
`Admin::ProductsController#product_params`.

Run `bundle exec herb lint` before committing.

### 4. Show it where it matters

- `app/views/admin/products/index.html.erb`: a 40px `:thumb` in a new leading
  column, falling back to the current placeholder.
- `app/views/orders/_product_browser.html.erb`: replace the emoji tile
  (`<div class="size-16 rounded-lg bg-muted ...">&#9749;</div>`) with the
  `:thumb` variant when attached, keeping the emoji as the fallback so products
  without a photo look unchanged.
- Optional follow-up: tapping the tile opens the `:card` variant full-width so
  the waiter can turn the tablet to the customer. This is the actual point of
  the feature; keep it in scope unless it grows a modal component we do not have.

Every `<img>` needs `alt` (the product name) and explicit `width`/`height` to
avoid layout shift in the browser list.

### 5. Seeds

`db/seeds.rb` attaches a couple of sample photos from `test/fixtures/files/` so
a fresh dev database exercises the image path instead of always hitting the
fallback.

### 6. Tests

- **Model**: attach a fixture file, assert `product.image.attached?`; assert the
  content-type and size validations reject a `.txt` and an oversized blob.
  Use `ActiveStorage::FixtureSet.blob` / `fixture_file_upload`.
- **Integration** (`test/controllers/admin/products_controller_test.rb`):
  `patch` with `fixture_file_upload` attaches; `remove_image` purges; a product
  from another store is still not reachable.
- **System**: skip. Native file inputs in headless Chrome buy little here, and
  the rendering path is covered by the integration test's HTML.

Test env already points at `service: :test` (`config/environments/test.rb:32`),
which writes to `tmp/storage`. Add `tmp/storage` cleanup if fixtures leak.

### 7. Ops

- **Kamal**: nothing. Volume is already declared. Back up
  `may_store_storage` alongside the database.
- **Railway**: create a volume on the web service, mount path `/rails/storage`,
  enable automated backups, and remember the service must stay at one replica.
- Document whichever we do in `docs/README.md` next to the deploy notes.

## Out of scope

- Multiple images per product / a gallery. `has_one_attached` until someone asks.
- Direct uploads. The admin form is a handful of uploads a month over the
  store's wifi; a straight multipart POST is fine and one fewer moving part.
- Image CDN, `srcset`, or blurhash placeholders.
