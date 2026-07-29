/// Non-web fallbacks: no browser storage or history to talk to.
String? readLocal(String key) => null;

void writeLocal(String key, String value) {}

void removeLocal(String key) {}

void replaceUrl(String url) {}
