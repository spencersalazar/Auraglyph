
NODES=nodes.json
GENERATOR=./generate_docs.py

docs: index.html audio.html control.html

index.html: audio.html
	cp audio.html index.html

audio.html: $(NODES) $(GENERATOR)
	$(GENERATOR) audio < $(NODES) > audio.html

control.html: $(NODES) $(GENERATOR)
	$(GENERATOR) control < $(NODES) > control.html


