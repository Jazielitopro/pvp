const IMPORT_KEY = "parryhook-ui-redesign-import";

const PAGE_ORDER = [
  "00 Benchmark",
  "01 Foundations",
  "02 Components",
  "03 Desktop",
  "04 Mobile",
  "05 Handoff",
];

const BOARD_SPECS = [
  { file: "00-benchmark.svg", page: "00 Benchmark" },
  { file: "01-foundations-components.svg", page: "01 Foundations" },
  { file: "02-components.svg", page: "02 Components" },
  { file: "03-desktop-hud.svg", page: "03 Desktop" },
  { file: "03-desktop-progression.svg", page: "03 Desktop" },
  { file: "03-desktop-season-profile.svg", page: "03 Desktop" },
  { file: "03-match-overlays.svg", page: "03 Desktop" },
  { file: "04-mobile-hud.svg", page: "04 Mobile" },
  { file: "04-mobile-progression.svg", page: "04 Mobile" },
  { file: "04-mobile-season.svg", page: "04 Mobile" },
  { file: "04-mobile-profile.svg", page: "04 Mobile" },
  { file: "05-handoff.svg", page: "05 Handoff" },
];

figma.showUI(__html__, {
  width: 520,
  height: 650,
  title: "Parryhook UI Redesign Importer",
});

function post(type, payload = {}) {
  figma.ui.postMessage(Object.assign({ type }, payload));
}

async function ensurePage(name) {
  let page = figma.root.children.find((candidate) => candidate.name === name);
  if (!page) {
    page = figma.createPage();
    page.name = name;
  }
  await page.loadAsync();
  return page;
}

function clearPreviousImport(page) {
  for (const node of Array.from(page.children)) {
    if (node.getPluginData(IMPORT_KEY) === "true") {
      node.remove();
    }
  }
}

function boardName(file) {
  return `Board / ${file.replace(/\.svg$/i, "")}`;
}

async function importBoards(files) {
  const supplied = new Map(files.map((item) => [item.name.toLowerCase(), item]));
  const missing = BOARD_SPECS.filter((spec) => !supplied.has(spec.file));
  if (missing.length > 0) {
    throw new Error(`Missing SVG boards: ${missing.map((spec) => spec.file).join(", ")}`);
  }

  const pages = new Map();
  for (const pageName of PAGE_ORDER) {
    const page = await ensurePage(pageName);
    clearPreviousImport(page);
    pages.set(pageName, page);
  }

  const nextX = new Map(PAGE_ORDER.map((pageName) => [pageName, 0]));
  const imported = new Map(PAGE_ORDER.map((pageName) => [pageName, []]));

  for (const spec of BOARD_SPECS) {
    post("progress", { message: `Importing ${spec.file}` });
    const page = pages.get(spec.page);
    const source = supplied.get(spec.file);
    const node = figma.createNodeFromSvg(source.svg);
    node.name = boardName(spec.file);
    node.setPluginData(IMPORT_KEY, "true");
    page.appendChild(node);
    node.x = nextX.get(spec.page);
    node.y = 0;
    nextX.set(spec.page, node.x + node.width + 120);
    imported.get(spec.page).push(node);
  }

  const desktopNodes = imported.get("03 Desktop");
  await figma.setCurrentPageAsync(pages.get("03 Desktop"));
  const starterPage = figma.root.children.find((page) => page.name === "Page 1");
  if (starterPage) {
    await starterPage.loadAsync();
    if (starterPage.children.length === 0) {
      starterPage.remove();
    }
  }
  if (desktopNodes.length > 0) {
    figma.viewport.scrollAndZoomIntoView(desktopNodes);
    figma.currentPage.selection = desktopNodes;
  }

  figma.notify("Parryhook UI Redesign imported into six pages.");
  post("done", {
    message: "Import complete. Review the six pages, then rename the Figma file to Parryhook UI Redesign.",
  });
}

figma.ui.onmessage = async (message) => {
  if (message.type === "cancel") {
    figma.closePlugin();
    return;
  }

  if (message.type !== "import-svgs") {
    return;
  }

  try {
    post("progress", { message: "Preparing six Figma pages..." });
    await importBoards(message.files);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    figma.notify(detail, { error: true });
    post("error", { message: detail });
  }
};
