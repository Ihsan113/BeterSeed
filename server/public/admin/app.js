"use strict";
const $ = (id) => document.getElementById(id);
let csrf = "",
  page = 1,
  auditPage = 1,
  search = "",
  selected = null,
  action = null,
  busy = false;
let names = Object.create(null),
  packCatalog = [],
  editingPack = null;
const messages = {
  catalog_changed:
    "Katalog berubah. Tutup formulir, muat ulang, lalu periksa harga terbaru.",
  invalid_pack:
    "Periksa harga dan status. Free harus 0 koin; Premium minimal 1 koin. Original Garden selalu gratis dan aktif.",
  admin_invalid_credentials:
    "Email, sandi, atau kode authenticator tidak cocok.",
  admin_unauthorized: "Sesi berakhir. Silakan masuk kembali.",
  admin_origin_required: "Buka dashboard melalui domain resmi server.",
  admin_csrf_required: "Sesi berubah. Muat ulang halaman sebelum mencoba lagi.",
  rate_limited: "Terlalu banyak percobaan. Tunggu beberapa menit.",
  invalid_request:
    "Periksa isian. Sandi minimal 12 karakter dan alasan minimal 5 karakter.",
  request_conflict:
    "Alamat email sudah digunakan atau perubahan bertabrakan. Muat ulang dan periksa lagi.",
  user_not_found: "Akun sudah tidak tersedia.",
  confirmation_mismatch: "Email konfirmasi tidak cocok.",
  google_managed_email: "Email akun Google dikelola melalui Google.",
  database_busy: "Layanan sedang menyelesaikan pekerjaan atau pemulihan. Tunggu sebentar lalu coba lagi.",
  invalid_backup: "Backup tidak valid, rusak, atau frasa sandi tidak cocok.",
  backup_key_mismatch: "Kunci server berbeda. Migrasi memerlukan TOKEN_PEPPER dan DATA_ENCRYPTION_KEY dari server asal.",
  backup_schema_mismatch: "Skema tidak cocok. Gunakan versi backend dan migrasi yang sama dengan server asal.",
  backup_missing_admin: "Backup harus memiliki setidaknya satu akun admin.",
  backup_too_large: "Data melebihi batas backup browser 32 MB. Gunakan backup database terkelola.",
  preview_expired: "Pratinjau kedaluwarsa atau file berubah. Periksa ulang file sebelum menyimpan.",
  mutation_conflict: "Tindakan ini sudah tercatat dengan nilai berbeda.",
};
function node(tag, text, cls) {
  const n = document.createElement(tag);
  if (text !== undefined) n.textContent = String(text);
  if (cls) n.className = cls;
  return n;
}
function notice(text, error = false) {
  $("notice").textContent = text;
  $("notice").className = error ? "error" : "";
  $("notice").hidden = !text;
}
function loginView() {
  csrf = "";
  selected = null;
  $("dashboard").hidden = true;
  $("identity").hidden = true;
  $("login-view").hidden = false;
  for (const d of document.querySelectorAll("dialog[open]")) d.close();
  $("detail-body").replaceChildren();
  $("users").replaceChildren();
  $("audit-list").replaceChildren();
  $("login-form").elements.password.value = "";
  $("login-form").elements.code.value = "";
}
async function api(path, method = "GET", body) {
  const controller = new AbortController(),
    timer = setTimeout(() => controller.abort(), path.startsWith("/database/") ? 180000 : 25000);
  try {
    const r = await fetch("/admin/api" + path, {
      method,
      credentials: "same-origin",
      cache: "no-store",
      signal: controller.signal,
      headers: {
        "Content-Type": "application/json",
        ...(csrf ? { "X-CSRF-Token": csrf } : {}),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    const result = await r.json();
    if (!r.ok) {
      if (r.status === 401 && path !== "/login") {
        loginView();
        notice(messages.admin_unauthorized, true);
      }
      throw Error(
        messages[result.error] || "Tindakan belum berhasil. Silakan coba lagi.",
      );
    }
    return result;
  } catch (e) {
    if (e instanceof TypeError || e.name === "AbortError")
      throw Error(
        "Koneksi terputus. Coba kembali; perubahan mungkin sudah tersimpan.",
      );
    throw e;
  } finally {
    clearTimeout(timer);
  }
}
async function guarded(fn) {
  if (busy) return;
  busy = true;
  document.body.setAttribute("aria-busy", "true");
  try {
    await fn();
  } catch (e) {
    notice(e.message, true);
  } finally {
    busy = false;
    document.body.removeAttribute("aria-busy");
  }
}
document.addEventListener(
  "click",
  (e) => {
    const localDownload = e.target instanceof HTMLAnchorElement && e.target.dataset.localDownload === "true" && e.target.href.startsWith("blob:");
    if (busy && !localDownload) {
      e.preventDefault();
      e.stopImmediatePropagation();
    }
  },
  true,
);
const date = (value) =>
  value
    ? new Date(value).toLocaleString("id-ID", {
        dateStyle: "medium",
        timeStyle: "short",
      })
    : "Belum pernah";
const number = (value) => Number(value).toLocaleString("id-ID");
async function overview() {
  const s = await api("/overview");
  $("stats").replaceChildren(
    ...[
      ["users", "Total pengguna"],
      ["verified", "Email terverifikasi"],
      ["activeSessions", "Sesi aktif"],
      ["suspended", "Akun ditangguhkan"],
      ["pendingPurchases", "Pembelian dalam proses"],
      ["pendingEmails", "Email dalam antrean"],
    ].map(([key, label]) => {
      const box = node("div", undefined, "stat");
      box.append(node("span", label), node("strong", number(s[key])));
      return box;
    }),
  );
}
async function users() {
  const data = await api("/users?" + new URLSearchParams({ search, page }));
  $("users").replaceChildren();
  for (const u of data.users) {
    const row = node("tr");
    row.append(
      node("td", u.email),
      node("td", u.provider === "google" ? "Google" : "Email"),
    );
    const status = node("td");
    status.append(
      node(
        "span",
        u.suspended
          ? "Ditangguhkan"
          : u.verified
            ? "Aktif"
            : "Belum diverifikasi",
        "badge" + (u.suspended ? " paused" : !u.verified ? " pending" : ""),
      ),
    );
    row.append(
      status,
      node("td", number(u.balance)),
      node("td", date(u.lastSync)),
    );
    const cell = node("td"),
      button = node("button", "Kelola", "quiet");
    button.addEventListener("click", () => guarded(() => detail(u.id)));
    cell.append(button);
    row.append(cell);
    $("users").append(row);
  }
  if (!data.users.length) {
    const row = node("tr"),
      cell = node("td", "Tidak ada pengguna yang cocok.", "empty");
    cell.colSpan = 6;
    row.append(cell);
    $("users").append(row);
  }
  $("page-info").textContent =
    `${number(data.total)} pengguna · Halaman ${page}`;
  $("previous").disabled = page <= 1;
  $("next").disabled = page * 25 >= data.total;
}
const actionLabels = {
  "admin.login": "Admin masuk",
  "user.create": "Pengguna ditambahkan",
  "user.update": "Akun diperbarui",
  "user.revoke_sessions": "Sesi dicabut",
  "wallet.adjust": "Saldo disesuaikan",
  "pack.grant": "Pack diberikan",
  "pack.revoke": "Pack dicabut",
  "user.delete": "Akun dihapus",
  "catalog.export": "Katalog diekspor", "catalog.import": "Katalog diimpor",
  "catalog.create": "Pack ditambahkan", "catalog.update": "Pack diperbarui",
  "database.export": "Backup database dibuat", "database.restore": "Database dipulihkan",
};
function logs(entries) {
  if (!entries.length) return [node("p", "Belum ada aktivitas.", "muted")];
  return entries.map((e) => {
    const box = node("div", undefined, "log");
    box.append(
      node("strong", actionLabels[e.action] || e.action),
      node("p", e.reason),
      node("small", date(e.created_at)),
    );
    if (e.details?.delta !== undefined)
      box.append(
        node(
          "p",
          `Perubahan: ${e.details.delta > 0 ? "+" : ""}${number(e.details.delta)} koin`,
        ),
      );
    if (e.details?.pack)
      box.append(node("p", names[e.details.pack] || e.details.pack));
    if (e.target_id)
      box.append(node("p", `ID pengguna: ${e.target_id}`, "small muted"));
    if (e.admin_id)
      box.append(node("p", `ID admin: ${e.admin_id}`, "small muted"));
    return box;
  });
}
async function audit() {
  const data = await api("/audit?page=" + auditPage);
  $("audit-list").replaceChildren(...logs(data.entries));
  $("audit-page").textContent = `Halaman ${auditPage}`;
  $("audit-previous").disabled = auditPage === 1;
  $("audit-next").disabled = data.entries.length < 50;
}
async function dashboard(me) {
  csrf = me.csrf;
  $("admin-email").textContent = me.email;
  $("identity").hidden = false;
  $("login-view").hidden = true;
  $("dashboard").hidden = false;
  await Promise.all([overview(), users(), loadPacks()]);
}
function addAction(parent, label, kind, cls = "quiet", extras = {}) {
  const b = node("button", label, cls);
  b.addEventListener("click", () => openAction(kind, extras));
  parent.append(b);
}
async function detail(id) {
  await loadPacks();
  const d = await api("/users/" + id);
  selected = d.user;
  const box = $("detail-body");
  box.replaceChildren(
    node("p", selected.email, "detail-email"),
    node(
      "p",
      selected.provider === "google" ? "Akun Google" : "Akun email",
      "muted",
    ),
  );
  const grid = node("div", undefined, "detail-grid");
  for (const [label, value] of [
    [
      "Status",
      selected.suspended
        ? "Ditangguhkan"
        : selected.verified
          ? "Aktif"
          : "Menunggu verifikasi",
    ],
    ["Leaf Coins", number(selected.balance)],
    [
      "Progres taman",
      `${number(d.garden.xp)} XP · ${d.garden.habitCount} kebiasaan`,
    ],
    ["Authenticator", selected.twoFactorEnabled ? "Aktif" : "Belum aktif"],
    ["Bergabung", date(selected.created_at)],
    ["Terakhir sinkron", date(selected.lastSync)],
  ]) {
    const item = node("div");
    item.append(node("span", label, "small muted"), node("strong", value));
    grid.append(item);
  }
  box.append(grid, node("h3", "Kelola akun"));
  const controls = node("div", undefined, "actions");
  if (selected.provider === "email") addAction(controls, "Ubah email", "email");
  addAction(
    controls,
    selected.suspended ? "Aktifkan akun" : "Tangguhkan akun",
    "suspend",
  );
  addAction(controls, "Cabut semua sesi", "sessions");
  addAction(controls, "Sesuaikan koin", "coins");
  box.append(controls, node("h3", "Akses pack"));
  for (const [pack, label] of Object.entries(names).filter(
    ([id]) => id !== "default",
  )) {
    const owned = d.packs.some((p) => p.pack_id === pack),
      row = node("div", undefined, "log");
    row.append(
      node("strong", label),
      node("p", owned ? "Dimiliki" : "Belum dimiliki", "muted"),
    );
    addAction(row, owned ? "Cabut akses" : "Berikan akses", "pack", "quiet", {
      pack,
      granted: !owned,
    });
    box.append(row);
  }
  box.append(node("h3", "Pembelian terakhir"));
  if (!d.purchases.length)
    box.append(node("p", "Belum ada pembelian.", "muted"));
  for (const p of d.purchases) {
    const row = node("div", undefined, "log");
    row.append(
      node(
        "strong",
        `${number(p.coins)} koin · ${{ credited: "Diproses", consumed: "Selesai", voided: "Dibatalkan" }[p.state]}`,
      ),
      node("small", date(p.created_at)),
    );
    box.append(row);
  }
  box.append(node("h3", "Perubahan saldo terakhir"));
  for (const l of d.ledger) {
    const row = node("div", undefined, "log");
    row.append(
      node("strong", `${l.delta > 0 ? "+" : ""}${number(l.delta)} koin`),
      node("small", date(l.created_at)),
    );
    box.append(row);
  }
  box.append(
    node("h3", "Aktivitas pengelola"),
    ...logs(d.audit),
    node("h3", "Hapus akun"),
  );
  const danger = node("div", undefined, "actions");
  addAction(danger, "Hapus permanen", "delete", "danger");
  box.append(danger);
  if (!$("detail-dialog").open) $("detail-dialog").showModal();
}
function field(name, label, type = "text", value = "", options) {
  const wrapper = node("label", label),
    input = node("input");
  input.name = name;
  input.type = type;
  input.value = value;
  input.required = true;
  if (options) Object.assign(input, options);
  wrapper.append(input);
  $("action-fields").append(wrapper);
  return input;
}
function openAction(kind, extras = {}) {
  action = {
    kind,
    id: selected?.id,
    email: selected?.email,
    suspended: !!selected?.suspended,
    ...extras,
    mutationId: crypto.randomUUID(),
  };
  $("action-form").reset();
  $("action-fields").replaceChildren();
  $("action-error").hidden = true;
  $("submit-action").className = kind === "delete" ? "danger" : "primary";
  $("submit-action").textContent =
    kind === "delete" ? "Hapus permanen" : "Simpan perubahan";
  const texts = {
    create: [
      "Tambah pengguna",
      "Akun email baru harus diverifikasi dan menyetujui kebijakan di aplikasi. Berikan sandi awal kepada pemilik melalui saluran aman; minta mereka menggantinya setelah masuk.",
    ],
    email: [
      "Ubah alamat email",
      "Akun akan keluar dari semua perangkat. Pemilik perlu memverifikasi email baru sebelum masuk kembali. Authenticator tetap diperlukan.",
    ],
    suspend: [
      action.suspended ? "Aktifkan kembali akun" : "Tangguhkan akun",
      "Sesi aktif akan dicabut. Data taman dan pembelian tetap tersimpan.",
    ],
    sessions: [
      "Cabut semua sesi",
      "Pengguna harus masuk kembali pada setiap perangkat.",
    ],
    coins: [
      "Sesuaikan Leaf Coins",
      "Masukkan nilai positif untuk menambah atau negatif untuk mengurangi. Tindakan dicatat terpisah dari pembelian Google Play.",
    ],
    pack: [
      extras.granted ? "Berikan akses pack" : "Cabut akses pack",
      `${names[extras.pack] || ""}. Tindakan ini tidak menagih atau mengembalikan pembayaran.`,
    ],
    delete: [
      "Hapus akun permanen",
      "Akun, taman, koin, dan akses pack akan dihapus. Tindakan ini tidak dapat dibatalkan dan tidak mengembalikan pembayaran. Ketik email pengguna untuk mengonfirmasi.",
    ],
  };
  $("action-title").textContent = texts[kind][0];
  $("action-description").textContent = texts[kind][1];
  if (kind === "create") {
    field("email", "Email pengguna", "email", "", { maxLength: 254 });
    field("password", "Sandi awal", "password", "", {
      minLength: 12,
      maxLength: 128,
      autocomplete: "new-password",
    });
  }
  if (kind === "email")
    field("email", "Email baru", "email", action.email, { maxLength: 254 });
  if (kind === "coins")
    field("delta", "Perubahan koin", "number", "", {
      min: -100000,
      max: 100000,
      step: 1,
    });
  if (kind === "delete")
    field("confirmation", "Konfirmasi email", "email", "", { maxLength: 254 });
  $("action-dialog").showModal();
}
$("action-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  if (busy) return;
  const form = e.currentTarget;
  if (!form.reportValidity()) return;
  const values = Object.fromEntries(new FormData(form));
  if (action.kind === "coins" && Number(values.delta) === 0) {
    $("action-error").textContent = "Perubahan koin tidak boleh nol.";
    $("action-error").hidden = false;
    return;
  }
  await guarded(async () => {
    try {
      let path = "/users" + (action.kind === "create" ? "" : "/" + action.id),
        method = "POST",
        body = { reason: values.reason };
      switch (action.kind) {
        case "create":
          Object.assign(body, {
            email: values.email,
            password: values.password,
          });
          break;
        case "email":
          method = "PATCH";
          body.email = values.email;
          break;
        case "suspend":
          method = "PATCH";
          body.suspended = !action.suspended;
          break;
        case "sessions":
          path += "/revoke-sessions";
          break;
        case "coins":
          path += "/coins";
          Object.assign(body, {
            delta: Number(values.delta),
            mutationId: action.mutationId,
          });
          break;
        case "pack":
          path += "/packs";
          Object.assign(body, { pack: action.pack, granted: action.granted });
          break;
        case "delete":
          method = "DELETE";
          body.confirmation = values.confirmation;
          break;
      }
      const result = await api(path, method, body);
      $("action-dialog").close();
      form.reset();
      notice("Perubahan berhasil disimpan.");
      if (action.kind === "delete") {
        $("detail-dialog").close();
        selected = null;
      } else await detail(result.id || action.id);
      await Promise.all([overview(), users()]);
    } catch (err) {
      $("action-error").textContent = err.message;
      $("action-error").hidden = false;
    }
  });
});
$("login-form").addEventListener("submit", (e) => {
  e.preventDefault();
  const form = e.currentTarget;
  guarded(async () => {
    try {
      const me = await api(
        "/login",
        "POST",
        Object.fromEntries(new FormData(form)),
      );
      form.reset();
      notice("");
      await dashboard(me);
    } finally {
      form.elements.password.value = "";
      form.elements.code.value = "";
    }
  });
});
$("logout").addEventListener("click", () =>
  guarded(async () => {
    await api("/logout", "POST", {});
    loginView();
    notice("Anda telah keluar.");
  }),
);
$("refresh").addEventListener("click", () =>
  guarded(() =>
    Promise.all([
      overview(),
      !$("packs-view").hidden
        ? loadPacks()
        : $("audit-view").hidden
          ? users()
          : audit(),
    ]),
  ),
);
$("search-form").addEventListener("submit", (e) => {
  e.preventDefault();
  search = $("search").value.trim();
  page = 1;
  guarded(users);
});
$("previous").addEventListener("click", () => {
  page = Math.max(1, page - 1);
  guarded(users);
});
$("next").addEventListener("click", () => {
  page++;
  guarded(users);
});
$("audit-previous").addEventListener("click", () => {
  auditPage = Math.max(1, auditPage - 1);
  guarded(audit);
});
$("audit-next").addEventListener("click", () => {
  auditPage++;
  guarded(audit);
});
for (const tab of ["users", "audit", "packs", "database"])
  $(tab + "-tab").addEventListener("click", () => {
    for (const name of ["users", "audit", "packs", "database"]) {
      $(name + "-view").hidden = name !== tab;
      $(name + "-tab").classList.toggle("selected", name === tab);
      $(name + "-tab").setAttribute("aria-pressed", String(name === tab));
    }
    if (tab === "audit") guarded(audit);
    if (tab === "packs") guarded(loadPacks);
  });
$("create-user").addEventListener("click", () => openAction("create"));
$("close-detail").addEventListener("click", () => $("detail-dialog").close());
$("cancel-action").addEventListener("click", () => {
  if (!busy) $("action-dialog").close();
});
$("action-dialog").addEventListener("cancel", (e) => {
  if (busy) e.preventDefault();
});
api("/me")
  .then(dashboard)
  .catch((e) => {
    loginView();
    if (e.message !== messages.admin_unauthorized) notice(e.message, true);
  });

async function loadPacks() {
  const result = await api("/packs");
  packCatalog = result.packs;
  names = Object.fromEntries(packCatalog.map((p) => [p.packId, p.name]));
  renderPacks();
}
function renderPacks() {
  const query = $("pack-search").value.trim().toLowerCase();
  const status = $("pack-filter").value;
  const packs = packCatalog.filter(p => (status === "all" || p.status === status) && `${p.name} ${p.packId}`.toLowerCase().includes(query));
  $("pack-count").textContent = `${number(packs.length)} dari ${number(packCatalog.length)} pack`;
  $("pack-list").replaceChildren(...packs.map(p => {
    const card = node("article", undefined, "pack-card");
    const head = node("div", undefined, "section-heading");
    head.append(node("span", p.packId, "small muted"), node("span", ({active:"Aktif",draft:"Draft",hidden:"Disembunyikan",retired:"Tidak dijual"})[p.status], "badge " + (p.status === "active" ? "" : "pending")));
    card.append(head, node("h3", p.name), node("p", p.description || "Belum ada deskripsi.", "muted"));
    const meta = node("div", undefined, "pack-meta");
    meta.append(node("strong", p.accessType === "free" ? "Gratis" : `${number(p.priceCoins)} Leaf Coins`), node("span", `Build ${p.minimumAppBuild}+ · Revisi ${p.revision}`, "small muted"));
    card.append(meta, node("p", p.packId === "default" ? "Tersedia untuk semua pengguna" : `${number(p.owners)} pemilik`, "small muted"));
    const edit = node("button", "Edit pack", "quiet"); edit.addEventListener("click", () => openPack(p)); card.append(edit);
    return card;
  }));
  if (!packs.length) $("pack-list").append(node("p", "Tidak ada pack yang cocok.", "empty"));
}
$("pack-search").addEventListener("input", renderPacks);
$("pack-filter").addEventListener("change", renderPacks);

function openPack(pack = null) {
  editingPack = pack;
  const form = $("pack-form");
  form.reset();
  $("pack-error").hidden = true;
  const data = pack || {
    packId: "",
    name: "",
    description: "",
    accessType: "premium",
    priceCoins: 180,
    status: "draft",
    minimumAppBuild: 59,
    displayOrder: 40,
  };
  for (const key of [
    "packId",
    "name",
    "description",
    "accessType",
    "priceCoins",
    "status",
    "minimumAppBuild",
    "displayOrder",
  ])
    form.elements[key].value = data[key];
  form.elements.packId.readOnly = !!pack;
  $("pack-dialog").showModal();
}
$("create-pack").addEventListener("click", () => openPack());
$("cancel-pack").addEventListener("click", () => {
  if (!busy) $("pack-dialog").close();
});
$("pack-dialog").addEventListener("cancel", (e) => {
  if (busy) e.preventDefault();
});
$("pack-form").elements.accessType.addEventListener("change", () => {
  if ($("pack-form").elements.accessType.value === "free")
    $("pack-form").elements.priceCoins.value = "0";
});
$("pack-form").addEventListener("submit", (e) => {
  e.preventDefault();
  if (busy || !e.currentTarget.reportValidity()) return;
  const data = Object.fromEntries(new FormData(e.currentTarget));
  delete data.confirmed;
  for (const key of ["priceCoins", "minimumAppBuild", "displayOrder"])
    data[key] = Number(data[key]);
  guarded(async () => {
    try {
      const key = data.packId;
      if (editingPack) {
        delete data.packId;
        data.expectedRevision = editingPack.revision;
      }
      await api(
        "/packs" + (editingPack ? "/" + encodeURIComponent(key) : ""),
        editingPack ? "PATCH" : "POST",
        data,
      );
      $("pack-dialog").close();
      await loadPacks();
      notice("Katalog tersimpan. Pemilik lama tetap memiliki akses.");
    } catch (err) {
      $("pack-error").textContent = err.message;
      $("pack-error").hidden = false;
    }
  });
});

let transfer = null;
function downloadJson(value, filename) {
  const url = URL.createObjectURL(new Blob([JSON.stringify(value, null, 2)], { type: "application/json" }));
  const link = node("a"); link.href = url; link.download = filename; link.dataset.localDownload = "true";
  document.body.append(link); link.click(); link.remove();
  setTimeout(() => URL.revokeObjectURL(url), 60000);
}
function transferField(name, label, type = "text", options = {}) {
  const wrapper = node("label", label), input = node("input");
  input.name = name; input.type = type; input.required = true;
  Object.assign(input, options); wrapper.append(input); $("transfer-fields").append(wrapper); return input;
}
function freshCredentials() {
  transferField("password", "Sandi admin saat ini", "password", { autocomplete: "current-password", maxLength: 128 });
  transferField("code", "Kode authenticator baru (tunggu kode berikutnya setelah login / backup)", "text", { inputMode: "numeric", pattern: "[0-9]{6}", maxLength: 6, autocomplete: "one-time-code" });
}
function transferReason() {
  transferField("reason", "Alasan tindakan", "text", { minLength: 5, maxLength: 500, placeholder: "Contoh: backup rutin sebelum pembaruan" });
}
function openTransfer(kind) {
  transfer = { kind, stage: "input" };
  $("transfer-form").reset(); $("transfer-fields").replaceChildren();
  $("transfer-preview").replaceChildren(); $("transfer-preview").hidden = true;
  $("transfer-error").hidden = true;
  const text = {
    packs: ["Impor garden pack", "Pilih JSON hasil ekspor. Edit harga, nama, akses, status, atau urutan secara massal. Pack baru memakai revision: null. Pack yang tidak ada di file tetap tersimpan."],
    export: ["Buat backup terenkripsi", "Simpan frasa sandi di tempat aman; tidak bisa dipulihkan oleh server. File berisi data pribadi dan akun admin. Frasa sandi berbeda dari sandi login admin."],
    restore: ["Periksa backup database", "Pilih file terenkripsi BetterSeed. Ringkasan akan ditampilkan sebelum pemulihan. File SQL tidak dijalankan melalui dashboard."],
  }[kind];
  $("transfer-title").textContent = text[0]; $("transfer-description").textContent = text[1];
  if (kind !== "export") transferField("file", "File JSON", "file", { accept: ".json,application/json" });
  if (kind !== "packs") transferField("passphrase", "Frasa sandi backup (minimal 16 karakter)", "password", { minLength: 16, maxLength: 256, autocomplete: kind === "export" ? "new-password" : "off" });
  if (kind === "export") {
    transferField("passphraseConfirm", "Ulangi frasa sandi backup", "password", { minLength: 16, maxLength: 256, autocomplete: "new-password" });
    freshCredentials(); transferReason();
  }
  $("transfer-submit").textContent = kind === "export" ? "Enkripsi & unduh backup" : "Periksa file";
  $("transfer-submit").className = "primary";
  $("transfer-dialog").showModal();
}
function clearTransfer() {
  transfer = null; $("transfer-form").reset(); $("transfer-fields").replaceChildren(); $("transfer-preview").replaceChildren();
}
$("cancel-transfer").addEventListener("click", () => { if (!busy) $("transfer-dialog").close(); });
$("transfer-dialog").addEventListener("close", clearTransfer);
$("transfer-dialog").addEventListener("cancel", e => { if (busy) e.preventDefault(); });
$("export-packs").addEventListener("click", () => guarded(async () => {
  downloadJson(await api("/packs/export"), "BetterSeed-garden-packs.json"); notice("Katalog JSON siap diunduh. Pertahankan revision saat mengedit pack lama.");
}));
$("import-packs").addEventListener("click", () => openTransfer("packs"));
$("database-export").addEventListener("click", () => openTransfer("export"));
$("database-import").addEventListener("click", () => openTransfer("restore"));
$("transfer-form").addEventListener("submit", e => {
  e.preventDefault(); const form = e.currentTarget;
  if (busy || !form.reportValidity()) return;
  guarded(async () => {
    $("transfer-error").hidden = true;
    try {
      const values = Object.fromEntries(new FormData(form));
      if (transfer.kind === "export") {
        if (values.passphrase !== values.passphraseConfirm) throw Error("Frasa sandi backup tidak cocok.");
        const result = await api("/database/export", "POST", { passphrase: values.passphrase, reason: values.reason, credentials: { password: values.password, code: values.code } });
        downloadJson(result, `BetterSeed-database-${new Date().toISOString().slice(0,19).replace(/:/g,"-")}.encrypted.json`);
        $("transfer-dialog").close(); notice("Backup terenkripsi siap diunduh. Pastikan file tersimpan sebelum menutup halaman."); return;
      }
      if (transfer.stage === "input") {
        const file = form.elements.file.files[0];
        if (!file || file.size > (transfer.kind === "packs" ? 2 : 46) * 1024 * 1024) throw Error("File terlalu besar. Batas katalog 2 MB, backup terenkripsi 46 MB.");
        let data; try { data = JSON.parse(await file.text()); } catch { throw Error("File bukan JSON yang valid."); }
        const isPack = transfer.kind === "packs";
        const preview = await api(isPack ? "/packs/import/preview" : "/database/preview", "POST", isPack ? data : { backup: data, passphrase: values.passphrase });
        transfer = { ...transfer, stage: "confirm", data, passphrase: values.passphrase, proof: preview.proof };
        $("transfer-fields").replaceChildren();
        const box = $("transfer-preview"); box.replaceChildren(node("h3", "Pratinjau perubahan")); box.hidden = false;
        if (isPack) {
          const labels = { create: "Tambah", update: "Ubah", unchanged: "Tetap" };
          for (const change of preview.changes) {
            const row = node("div", undefined, "log");
            row.append(node("strong", `${labels[change.action]} · ${change.after.name} (${change.packId})`));
            for (const key of ["name","description","accessType","priceCoins","status","minimumAppBuild","displayOrder"]) {
              if (!change.before || change.before[key] !== change.after[key]) row.append(node("p", `${key}: ${change.before?.[key] ?? "—"} → ${change.after[key]}`));
            }
            box.append(row);
          }
          $("transfer-submit").textContent = "Terapkan impor";
        } else {
          box.append(node("p", `Waktu backup: ${date(preview.createdAt)} · ${(preview.bytes/1024/1024).toFixed(2)} MB`));
          const list = node("dl", undefined, "backup-counts");
          for (const table of preview.tables) list.append(node("dt", table.name), node("dd", number(table.rows)));
          box.append(list, node("p", "Seluruh data saat ini diganti. Sesi pengguna dan admin berakhir. Masuk kembali memakai akun admin dari backup, dengan kode authenticator berikutnya.", "form-error"));
          transferField("safetyBackupSaved", "Saya sudah mengunduh cadangan terbaru database tujuan.", "checkbox");
          transferField("confirmation", "Ketik RESTORE untuk mengganti database", "text", { pattern: "RESTORE", autocomplete: "off" });
          freshCredentials(); $("transfer-submit").textContent = "Pulihkan database"; $("transfer-submit").className = "danger";
        }
        transferReason(); $("transfer-title").focus(); return;
      }
      if (transfer.kind === "packs") {
        const result = await api("/packs/import", "POST", { document: transfer.data, proof: transfer.proof, reason: values.reason });
        $("transfer-dialog").close(); await loadPacks(); notice(`${number(result.changed)} pack diperbarui. Kepemilikan dan pack lain tetap tersimpan.`);
      } else {
        await api("/database/restore", "POST", { backup: transfer.data, passphrase: transfer.passphrase, proof: transfer.proof, reason: values.reason,
          confirmation: values.confirmation, safetyBackupSaved: values.safetyBackupSaved === "on", credentials: { password: values.password, code: values.code } });
        $("transfer-dialog").close(); loginView(); notice("Database berhasil dipulihkan. Masuk kembali menggunakan akun admin dari backup dan kode authenticator berikutnya.");
      }
    } catch (error) {
      $("transfer-error").textContent = error.message; $("transfer-error").hidden = false;
    } finally {
      for (const name of ["password", "code"]) if (form.elements[name]) form.elements[name].value = "";
    }
  });
});
