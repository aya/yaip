# target openstack: Call openstack ARGS
.PHONY: openstack
openstack: docker-build-openstack
	$(call openstack,$(ARGS))

# target openstack-image-create: Call openstack image create PACKER_ISO_NAME with file PACKER_ISO_FILE
.PHONY: openstack-image-create
openstack-image-create: $(PACKER_ISO_FILE) docker-build-openstack
	$(call openstack,$(OPENSTACK_ARGS) image create --disk-format raw --container-format bare --file $(PACKER_ISO_FILE) "$(PACKER_ISO_NAME)")
