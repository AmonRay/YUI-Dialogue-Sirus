import io


def load(path):
    return io.open(path, 'r', encoding='utf-8', newline='').read()


def save(path, text):
    io.open(path, 'w', encoding='utf-8', newline='').write(text)


def rep(text, old, new, label, nl):
    old = old.replace('\n', nl)
    new = new.replace('\n', nl)
    assert text.count(old) == 1, 'NOT UNIQUE: ' + label
    print('ok', label)
    return text.replace(old, new, 1)


p = 'CHANGELOG.md'
t = load(p)
nl = '\r\n' if '\r\n' in t else '\n'

t = rep(t, '### Новое из оригинала (1.0.7-c)', '''### Клиентские окна

- **Диалог больше не остаётся поверх окна трансмогрификации.** На Sirus трансмогрификация
  открывается из разговора без завершения gossip: клиент показывает своё окно и присылает опции
  заново, поэтому диалог закрывался по показу окна и тут же рисовался снова. Теперь, пока открыто
  окно трансмогрификации, коллекций или табарда, диалог не показывается, а закрытие срабатывает ещё
  и по клиентскому событию открытия окна.

### Новое из оригинала (1.0.7-c)''', 'changelog transmog section', nl)

save(p, t)

p = 'DialogueUI.toc'
t = load(p)
nl = '\r\n' if '\r\n' in t else '\n'
t = rep(t, '''# 1.0.9 camera: the focus zoom keeps a readable distance instead of orbiting 3 yards behind the player''',
        '''# 1.0.9 panels: the dialogue no longer comes back over the transmogrifier window
# 1.0.9 camera: the focus zoom keeps a readable distance instead of orbiting 3 yards behind the player''',
        'toc panel note', nl)
save(p, t)
