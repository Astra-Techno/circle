<?php

declare(strict_types=1);

namespace Circle\Core;

final class Router
{
    /** @var array<string, array<array{pattern: string, handler: callable, middleware: string[]}>> */
    private array $routes = [];

    /** @var array<string, callable> */
    private array $middleware = [];

    /** @var string[] */
    private array $groupMiddleware = [];

    private string $prefix = '';

    public function registerMiddleware(string $name, callable $handler): void
    {
        $this->middleware[$name] = $handler;
    }

    /** @param string[] $middleware */
    public function group(string $prefix, array $middleware, callable $callback): void
    {
        $prevPrefix = $this->prefix;
        $prevMiddleware = $this->groupMiddleware;

        $this->prefix = $prevPrefix . $prefix;
        $this->groupMiddleware = array_merge($prevMiddleware, $middleware);

        $callback($this);

        $this->prefix = $prevPrefix;
        $this->groupMiddleware = $prevMiddleware;
    }

    /** @param string[] $middleware */
    public function get(string $path, callable $handler, array $middleware = []): void
    {
        $this->addRoute('GET', $path, $handler, $middleware);
    }

    /** @param string[] $middleware */
    public function post(string $path, callable $handler, array $middleware = []): void
    {
        $this->addRoute('POST', $path, $handler, $middleware);
    }

    /** @param string[] $middleware */
    public function put(string $path, callable $handler, array $middleware = []): void
    {
        $this->addRoute('PUT', $path, $handler, $middleware);
    }

    /** @param string[] $middleware */
    public function patch(string $path, callable $handler, array $middleware = []): void
    {
        $this->addRoute('PATCH', $path, $handler, $middleware);
    }

    /** @param string[] $middleware */
    public function delete(string $path, callable $handler, array $middleware = []): void
    {
        $this->addRoute('DELETE', $path, $handler, $middleware);
    }

    /** @param string[] $middleware */
    private function addRoute(string $method, string $path, callable $handler, array $middleware): void
    {
        $fullPath = $this->prefix . $path;
        $pattern = $this->pathToPattern($fullPath);
        $allMiddleware = array_merge($this->groupMiddleware, $middleware);

        $this->routes[$method][] = [
            'pattern' => $pattern,
            'handler' => $handler,
            'middleware' => $allMiddleware,
        ];
    }

    private function pathToPattern(string $path): string
    {
        $path = rtrim($path, '/') ?: '/';
        return '#^' . preg_replace('#\{([a-zA-Z_]+)\}#', '(?P<$1>[a-zA-Z0-9_-]+)', $path) . '$#';
    }

    public function dispatch(Request $request): never
    {
        if ($request->method === 'OPTIONS') {
            Response::noContent();
        }

        $routes = $this->routes[$request->method] ?? [];

        foreach ($routes as $route) {
            if (preg_match($route['pattern'], $request->path, $matches)) {
                $params = array_filter($matches, 'is_string', ARRAY_FILTER_USE_KEY);
                $request = $request->withParams($params);

                $handler = $this->buildPipeline($route['handler'], $route['middleware']);
                $handler($request);
                exit;
            }
        }

        Response::notFound('Endpoint not found');
    }

    private function buildPipeline(callable $handler, array $middlewareNames): callable
    {
        $pipeline = $handler;

        foreach (array_reverse($middlewareNames) as $name) {
            if (!isset($this->middleware[$name])) {
                continue;
            }
            $mw = $this->middleware[$name];
            $next = $pipeline;
            $pipeline = static function (Request $request) use ($mw, $next): void {
                $mw($request, $next);
            };
        }

        return $pipeline;
    }
}
