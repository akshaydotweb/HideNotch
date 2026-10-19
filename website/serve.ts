import index from "./index.html";

const server = Bun.serve({
  port: Number(process.env.PORT ?? 3000),
  routes: { "/": index },
  development: process.env.NODE_ENV !== "production",
});

console.log(`HideNotch website running at ${server.url}`);
