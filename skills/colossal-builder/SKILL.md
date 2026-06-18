---
name: colossal-builder
description: Use the Colossal Storefront SDK (@colossal-sh/storefront-sdk) in a React app. Use when wiring up a storefront's data layer — initializing the client, mounting QueryClientProvider + CartProvider, fetching products (useProducts/useProduct), store metadata (useStore/useCurrentStore), managing cart state (useCartContext), creating checkout sessions (useCreateCheckoutSession), or running custom GraphQL via executeStorefront. Covers the full hook surface, provider setup, and helpers (formatPrice, toSimpleProduct, etc.). Generic React guidance — for the Colossal React Vite template specifics, pair with colossal-template-builder.
---

# Colossal Builder

Generic guide to `@colossal-sh/storefront-sdk` in a React app. Documents the public hook surface, provider setup, types, and helpers as exported from `src/index.ts`.

For framework-agnostic concepts: still applicable. For the Colossal React Vite template's file map and 3-file CSS architecture, see the `colossal-template-builder` sibling skill.

---

## Package

```jsonc
// package.json
{
  "dependencies": {
    "@colossal-sh/storefront-sdk": "^1.0.0",
    "@tanstack/react-query": "^5.0.0"
  }
}
```

Peer dependency: `react ^18 || ^19`. The SDK ships ESM-only (`"type": "module"`).

---

## Setup (3 steps)

### 1. Initialize the GraphQL client

Call once at module load — before any component mounts:

```ts
import { initStorefrontClient } from "@colossal-sh/storefront-sdk";

initStorefrontClient({
  // url defaults to https://api-staging.colossal.sh
  url: import.meta.env.VITE_API_URL,
  // optional: function called on every request — return fresh auth headers
  getHeaders: () => ({ "X-Store-Uid": STORE_UID }),
});
```

If a hook fires before `initStorefrontClient()` runs, `executeStorefront` throws `"Storefront client not initialized."`. The client uses `credentials: "include"` and `errorPolicy: "all"`.

### 2. Mount providers

```tsx
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { CartProvider } from "@colossal-sh/storefront-sdk";

const queryClient = new QueryClient();

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <CartProvider storeUid={STORE_UID}>
        {/* app */}
      </CartProvider>
    </QueryClientProvider>
  );
}
```

`<CartProvider>` props:

| Prop | Required | Default | Purpose |
|---|---|---|---|
| `storeUid` | yes | - | Identifies the store; used as the cart-storage key |
| `storage` | no | `localStorageCartIds` | Pluggable cart-id persistence (`CartIdStorage` interface) |

Currency is read off the server-resolved cart, not passed as a prop. Default storage uses `localStorage` under key `cart-${storeUid}`; it's SSR-safe (no-ops when `window` is undefined). Provide a custom `CartIdStorage` for cookies, IndexedDB, or in-memory testing.

### 3. Use hooks anywhere below the providers

Top-level imports:

```ts
import {
  // Store / workspace
  useStore, useCurrentStore,
  // Products
  useProducts, useProduct, useStoreProducts, useStoreProduct,
  // Cart (high level — recommended)
  useCartContext, useCartOptional,
  // Cart (low level — raw mutations)
  useCart, useCreateCart, useAddToCart, useUpdateCartLine, useRemoveCartLine,
  // Checkout
  useCreateCheckoutSession,
} from "@colossal-sh/storefront-sdk";
```

---

## Hooks

### Store / workspace

#### `useStore(identifier?, isDebug?, options?)`

```ts
useStore({ uid?: string; domain?: string }, isDebug?: boolean, options?: UseQueryOptions)
```

Fetches store details by `uid` OR `domain`. Disabled (no fetch) when both are missing. `isDebug=true` polls every 3s. Throws `"Either uid or domain should be provided"` only if the queryFn runs without either — in practice `enabled: !!uid || !!domain` keeps it from running.

```tsx
const { data } = useStore({ uid: STORE_UID });
const storeName = data?.storeDetails?.name;
```

#### `useCurrentStore(isDebug?)`

For host-context resolution (the API infers store from request origin). `isDebug=true` polls every 3s.

### Products

The SDK exposes both **raw** query hooks (return TanStack Query results with full GraphQL shapes) and **simplified** hooks (return mapped, easy-to-render objects). Prefer the simplified ones for UI; reach for raw when you need full graph access.

| Simplified | Raw |
|---|---|
| `useProducts(storeUid?)` | `useStoreProducts(storeUid?, isDebug?, options?)` |
| `useProduct(productUid)` | `useStoreProduct(productUid, isPreview?, options?)` |

#### `useProducts(storeUid?)`

```tsx
const { products, isLoading, isError } = useProducts(STORE_UID);
// products: SimpleProduct[]
```

#### `useProduct(productUid)`

```tsx
const { product, isLoading, isError } = useProduct(uid);
// product: SimpleProduct | null
```

#### `useStoreProducts(storeUid?, isDebug?, options?)`

Raw query. Returns `UseQueryResult<{ productsByStoreUid: StoreProduct[] }, Error>`. `isDebug=true` polls every 10s. `enabled: !!storeUid`.

#### `useStoreProduct(productUid, isPreview?, options?)`

Raw query. `staleTime: 0` (refetches on every mount). `isPreview=true` polls every 1s.

### Cart (high-level)

**Use `useCartContext()` for almost everything.** It owns cart-id persistence, drawer state, optimistic creation, and retry-on-stale-cart.

#### `useCartContext()` — throws if no provider

#### `useCartOptional()` — returns `null` if no provider

`CartContextValue`:

```ts
{
  cartId: string | null;
  cart: ReturnType<typeof useCart>["data"];   // raw cart query data
  items: SimpleLineItem[];
  subtotal: number;
  currency: string | null;   // null until the first cart loads
  itemCount: number;
  isLoading: boolean;
  error: Error | null;

  // Drawer
  isOpen: boolean;
  openCart: () => void;
  closeCart: () => void;

  // Mutations (auto-create cart, refetch, etc.)
  addItem: (productUid: string) => Promise<void>;
  removeItem: (lineItemUid: string) => Promise<void>;
  updateQuantity: (lineItemUid: string, quantity: number) => Promise<void>;
  refreshCart: () => void;   // clears cartId — forces a fresh cart on next addItem
}
```

**Behavior of `addItem`:**

1. If `cartId` is null → creates a cart, persists the new id via storage.
2. Adds the line.
3. If add returns `NOT_FOUND` (cart was deleted server-side) → wipes the stale id, creates a fresh cart, retries the add.
4. On success → refetches the cart and opens the drawer (`isOpen = true`).

```tsx
function AddButton({ productUid }: { productUid: string }) {
  const { addItem } = useCartContext();
  return <button onClick={() => addItem(productUid)}>Add to bag</button>;
}
```

### Cart (low-level)

Use only when `useCartContext` doesn't fit (e.g. SSR, custom optimistic UI, multiple carts). All return TanStack Query mutations/queries with the GraphQL response shape unmodified.

| Hook | Type |
|---|---|
| `useCart(uid, { enabled? })` | Query for a cart by uid |
| `useCreateCart()` | Mutation → `CreateCartMutationVariables` |
| `useAddToCart()` | Mutation → `AddToCartMutationVariables` |
| `useUpdateCartLine()` | Mutation → `UpdateCartLineMutationVariables` |
| `useRemoveCartLine()` | Mutation → `RemoveCartLineMutationVariables` |

### Checkout

#### `useCreateCheckoutSession()`

```tsx
const createCheckout = useCreateCheckoutSession();

async function checkout(cartUid: string) {
  const result = await createCheckout.mutateAsync({ input: { cartUid } });
  if (result.success && result.data?.uid) {
    window.location.href = result.data.url; // or wherever checkout lives
  }
}
```

Invalidates `checkoutKeys.all` queries on success.

---

## Utilities (pure functions — no React)

| Function | Purpose |
|---|---|
| `formatPrice(amountMinor, currency, locale?)` | Intl currency formatter; converts minor to major and formats. Zero-decimal-currency aware. |
| `toSimpleProduct(product)` | Map raw `StoreProduct` to `SimpleProduct`. Currency comes off the product. |
| `toSimpleLineItem(lineItem)` | Map raw line item to `SimpleLineItem`. Currency comes off the line item. |
| `getProductName(product, fallback?)` | Handles both storefront and admin product shapes |
| `getProductImage(product)` | First image URL or undefined |
| `getProductImages(product)` | All image URLs |
| `getDefaultVariantPrice(variant)` | Resolves LINEAR / VOLUME pricing |
| `getFormattedProductPrice(product, locale?)` | "$9.99" or "$9.99/month". Reads currency off the product. |
| `getProductRecurringInterval(product)` | "month" / "year" / undefined |
| `getTrialDuration(product)` | ISO 8601 duration or undefined |
| `getInventoryCount(product)` | number or null |
| `getLineItemName/Price/Image/Subtotal(lineItem)` | Mirrors product helpers for cart lines |

Use these instead of reaching into the GraphQL response shape — they handle both storefront-public and admin-published variants and unwrap nullable chains.

---

## Types

```ts
// Domain types
import type {
  SimpleProduct, SimpleLineItem, Deliverable,
  CartContextValue, CartIdStorage,
  CheckoutSession, StoreOrder, StoreProduct, StoreProductDetail,
} from "@colossal-sh/storefront-sdk";
```

`SimpleProduct`:
```ts
{
  uid: string;
  name: string;
  tagline: string | undefined;
  description: string | undefined;
  unitAmount: number | null;          // minor units; null when no default price
  currency: string;
  recurringInterval: string | null;   // "month" | "year" | null
  trialDuration: string | null;       // ISO 8601 duration
  images: string[];
  deliverables: Deliverable[];
}
```

`SimpleLineItem`:
```ts
{
  uid: string;
  productUid: string;
  name: string;
  unitAmount: number;     // minor units
  totalAmount: number;    // minor units; server-resolved, tier-aware
  currency: string;
  imageUrl: string | undefined;
  quantity: number;
}
```

`Deliverable`:
```ts
{ uid: string; name: string; type: string; config?: unknown }
```

---

## Money & currency

Every money value the SDK returns is an integer in the currency's smallest unit, paired with a `currency: string` field on the same object.

### What you read off the wire

- Money is `int` minor units. USD `1999` means `$19.99`. JPY `1500` means `¥1500` (zero-decimal currencies are not multiplied by 100).
- Every money field is paired with `currency` on the same type. Read currency from the same object as the amount, not from a parent.
- Use `formatPrice(amountMinor, currency, locale?)` to display. It handles zero-decimal currencies for you.
- `unitAmount` can be `null` on `SimpleProduct` (no default price configured). It is never `null` on `SimpleLineItem` (line items can't exist without a price).
- `cart.currency` is `null` until the first cart loads. Guard `formatPrice` calls on the cart subtotal.
- `SimpleLineItem.unitAmount` and `totalAmount` are server-resolved and tier-aware. Render them; don't compute totals client-side.

### Field naming on GraphQL types

- Money fields paired with a unit name end in `Amount` and are `Int!` (e.g. `taxAmount`, `unitPriceAmount`, `totalAmount`, `subtotalAmount`).
- A singular money field on a type uses bare `amount` (e.g. `Payment.amount`, `ShippingOption.amount`).
- `Float!` aliases on older fields (e.g. `Order.tax`, `OrderLineItem.unitPrice`) are marked `@deprecated` in the schema. Select the `*Amount: Int!` field instead.

---

## Imperative fetchers (for SSR / loaders)

Same data the hooks use, but as plain async functions — no React, no provider. Useful in route loaders, server functions, build-time generators.

| Function | Returns |
|---|---|
| `fetchCurrentStore()` | `{ currentStore? }` |
| `fetchStore({ uid?, domain? })` | `{ storeDetails? }` |
| `fetchStoreThemeConfig(domain)` | theme config |
| `fetchProducts(storeUid, currency?)` | `SimpleProduct[]` |
| `fetchProduct(productUid)` | `SimpleProduct \| null` |
| `fetchStoreProducts(storeUid)` | raw GraphQL shape |
| `fetchStoreProduct(productUid)` | raw GraphQL shape |

These also require `initStorefrontClient()` to have run.

---

## Custom GraphQL queries

For anything the hooks don't cover, run raw GraphQL via `executeStorefront`:

```ts
import { executeStorefront, graphql } from "@colossal-sh/storefront-sdk";

const MY_QUERY = graphql(/* GraphQL */ `
  query MyCustomQuery($uid: String!) {
    something(uid: $uid) { id name }
  }
`);

const data = await executeStorefront(MY_QUERY, { uid });
```

`graphql` is the codegen-typed document tag — variables and result types are inferred. For curried use, `executeStorefrontWithVariables(MY_QUERY)` returns `(vars) => Promise<TResult>`.

### Pre-built operation documents

These are exported if you need to compose, debug, or pass to other clients:

- Cart: `GET_CART`, `CREATE_CART`, `ADD_TO_CART`, `UPDATE_CART_LINE`, `REMOVE_CART_LINE`
- Checkout: `CREATE_CHECKOUT_SESSION`, `GET_CHECKOUT_SESSION`, `UPDATE_CHECKOUT_SESSION`, `COMPLETE_CHECKOUT_SESSION`
- Products: `GET_STOREFRONT_PRODUCT`, `GET_STOREFRONT_PRODUCTS`
- Store: `GET_CURRENT_STORE`, `GET_STORE_DETAILS_BY_UID`, `GET_STORE_DETAILS_BY_DOMAIN`, `GET_STORE_THEME_CONFIG`
- Other: `GET_PUBLIC_ORDER_DETAILS`, `GET_PAYMENT_METHODS`, `GET_ENABLED_BROWSER_APPS`

### Query key factories

For TanStack Query invalidation:

```ts
import { cartKeys, checkoutKeys } from "@colossal-sh/storefront-sdk";

queryClient.invalidateQueries({ queryKey: cartKeys.all });
queryClient.invalidateQueries({ queryKey: cartKeys.detail(cartUid) });
queryClient.invalidateQueries({ queryKey: checkoutKeys.session(uid) });
```

---

## Common patterns

### Product grid

```tsx
function ProductGrid() {
  const { products, isLoading } = useProducts(STORE_UID);
  if (isLoading) return <Skeleton />;
  return (
    <ul>
      {products.map((p) => (
        <li key={p.uid}>
          <img src={p.images[0]} alt={p.name} />
          <h3>{p.name}</h3>
          {p.unitAmount !== null && <p>{formatPrice(p.unitAmount, p.currency)}</p>}
        </li>
      ))}
    </ul>
  );
}
```

### Product detail page

```tsx
function ProductPage({ uid }: { uid: string }) {
  const { product, isLoading } = useProduct(uid);
  const { addItem } = useCartContext();
  if (isLoading || !product) return <Skeleton />;
  return (
    <article>
      <h1>{product.name}</h1>
      <p>{product.tagline}</p>
      {product.unitAmount !== null && (
        <p>{formatPrice(product.unitAmount, product.currency)}</p>
      )}
      <button onClick={() => addItem(product.uid)}>Add to bag</button>
    </article>
  );
}
```

### Cart drawer

```tsx
function CartDrawer() {
  const { items, subtotal, currency, isOpen, closeCart, removeItem, updateQuantity } = useCartContext();
  if (!isOpen) return null;
  return (
    <aside>
      {items.map((item) => (
        <div key={item.uid}>
          <span>{item.name}</span>
          <input
            type="number"
            value={item.quantity}
            onChange={(e) => updateQuantity(item.uid, Number(e.target.value))}
          />
          <button onClick={() => removeItem(item.uid)}>Remove</button>
        </div>
      ))}
      {currency && <p>Subtotal: {formatPrice(subtotal, currency)}</p>}
      <button onClick={closeCart}>Close</button>
    </aside>
  );
}
```

### Checkout

```tsx
function CheckoutButton() {
  const { cartId, itemCount } = useCartContext();
  const createCheckout = useCreateCheckoutSession();
  if (!cartId || itemCount === 0) return null;
  return (
    <button
      disabled={createCheckout.isPending}
      onClick={async () => {
        const result = await createCheckout.mutateAsync({ input: { cartUid: cartId } });
        if (result.success && result.data?.url) window.location.href = result.data.url;
      }}
    >
      Checkout
    </button>
  );
}
```

---

## Gotchas

- **`initStorefrontClient` must run before any hook fires.** Call it at module-load (top of `main.tsx`/`index.tsx`), not inside a component.
- **`useCartContext` throws** if `<CartProvider>` isn't an ancestor — use `useCartOptional` if optional usage is needed.
- **`useStoreProduct` has `staleTime: 0`** — every mount triggers a refetch. Pass `options` to override.
- **`addItem` opens the cart drawer on success.** If you don't want this, don't use `useCartContext` — wire `useAddToCart` directly.
- **`refreshCart()` clears the cart id**, it doesn't refetch. Next `addItem` will create a fresh cart.
- **`getHeaders` runs on every request.** Don't compute once — the function is invoked per call so auth tokens stay fresh.
- **`errorPolicy: "all"`** means partial errors don't reject the promise. Check `result.<operation>.success` and `.errors` on mutations.
